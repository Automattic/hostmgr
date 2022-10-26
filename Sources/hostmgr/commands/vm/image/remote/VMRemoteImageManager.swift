import Foundation
import Cocoa
import libhostmgr

import IOKit.pwr_mgt

class SystemSleepManager {

    private let reason: String
    private var assertionID: IOPMAssertionID = 0

    init(reason: String) {
        self.reason = reason
    }

    /// Re-enable sleep mode after disabling it
    ///
    /// Returns a boolean indicating success
    @discardableResult
    func enable() -> Bool {
        return IOPMAssertionRelease(assertionID) == kIOReturnSuccess
    }

    /// Disable Sleep until such time as `enable` is called
    ///
    /// Returns a boolean indicating success
    @discardableResult
    func disable() -> Bool {
        return IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        ) == kIOReturnSuccess
    }

    static func disableSleepFor(reason: String = "Running Operation", _ callback: () throws -> Void) rethrows {
        let manager = SystemSleepManager(reason: reason)
        manager.disable()
        try callback()
        manager.enable()
    }
}

struct VMRemoteImageManager {

    private let s3Manager: S3ManagerProtocol

    init(s3Manager: S3ManagerProtocol? = nil) {
        let bucket: String = Configuration.shared.vmImagesBucket
        let region: String = Configuration.shared.vmImagesRegion

        self.s3Manager = s3Manager ?? S3Manager(bucket: bucket, region: region)
    }

    func getManifest() async throws -> [String] {
        guard
            let object = try await self.s3Manager.lookupObject(atPath: "manifest.txt"),
            let bytes = try await self.s3Manager.download(object: object),
            let manifestString = String(data: bytes, encoding: .utf8)
        else {
            return []
        }

        return manifestString
            .split(separator: "\n")
            .map { String($0) }
    }

    func getImage(forPath path: String) async throws -> RemoteVMImage? {
        let basename = (path as NSString).deletingPathExtension
        let objects = try await s3Manager.listObjects(startingWith: basename)

        guard
            objects.count == 2,
            let imageObject = objects.first(where: { $0.key.hasSuffix(".pvmp") }),
            let checksumObject = objects.first(where: { $0.key.hasSuffix(".sha256.txt") })
        else {
            return nil
        }

        return RemoteVMImage(imageObject: imageObject, checksumKey: checksumObject.key)
    }

    func download(
        image: RemoteVMImage,
        to destination: URL,
        progressCallback: FileTransferProgressCallback? = nil
    ) async throws {
        _ = try await self.s3Manager.download(
            object: image.imageObject,
            to: destination,
            progressCallback: progressCallback
        )
    }

    func list(prefix: String = "images/") async throws -> [RemoteVMImage] {
        let objects = try await self.s3Manager.listObjects(startingWith: prefix)
        return remoteImagesFrom(objects: objects)
    }

    private func remoteImagesFrom(objects: [S3Object]) -> [RemoteVMImage] {
        let imageObjects = objects
            .filter { $0.key.hasSuffix(".pvmp") }

        let checksums = objects
            .filter { $0.key.hasSuffix(".sha256.txt") }
            .map(\.key)

        return imageObjects.compactMap { object in
            let filename = URL(fileURLWithPath: object.key).lastPathComponent  // filename = my-image.pvmp
            let basename = (filename as NSString).deletingPathExtension        // basename = my-image

            let checksumKey = "images/" + basename + ".sha256.txt"

            guard checksums.contains(checksumKey) else {
                return nil
            }

            return RemoteVMImage(imageObject: object, checksumKey: checksumKey)
        }
    }
}
