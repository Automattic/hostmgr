import Foundation
import Cocoa
import SotoS3
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

    struct RemoteImage {
        let imageObject: S3Object
        let checksumObject: S3Object

        var imagePath: String {
            imageObject.key
        }

        var fileName: String {
            (imageObject.key as NSString).lastPathComponent
        }

        var basename: String {
            (fileName as NSString).deletingPathExtension
        }

        init(imageObject: S3Object, checksumObject: S3Object) {
            self.imageObject = imageObject
            self.checksumObject = checksumObject
        }
    }

    private let bucket: String = Configuration.shared.vmImagesBucket
    private let region: Region = Configuration.shared.vmImagesRegion

    func getManifest() throws -> [String] {
        guard
            let manifest = try S3Manager().getFileBytes(region: region, bucket: bucket, key: "manifest.txt"),
            let manifestString = String(data: manifest, encoding: .utf8)
        else {
            return []
        }

        return manifestString
            .split(separator: "\n")
            .map { String($0) }
    }

    func getImage(forPath path: String) throws -> RemoteImage? {

        let basename = (path as NSString).deletingPathExtension
        let objects = try S3Manager().listObjects(region: region, bucket: bucket, startingWith: basename)

        /// There should only be two objects — the VM image, and it's checksum file
        guard
            objects.count == 2,
            let imageObject = objects.first(where: { $0.key?.hasSuffix(".pvmp") ?? false }),
            let imageObjectKey = imageObject.key,
            let imageObjectSize = imageObject.size,
            let checksumObject = objects.first(where: { $0.key?.hasSuffix(".sha256.txt") ?? false}),
            let checksumObjectKey = checksumObject.key
        else {
            return nil
        }

        return RemoteImage(
            imageObject: S3Object(key: imageObjectKey, size: Int(imageObjectSize)),
            checksumObject: S3Object(key: checksumObjectKey)
        )
    }

    func download(
        image: RemoteImage,
        to destination: URL,
        progressCallback: FileTransferProgressCallback? = nil
    ) throws {
        let region = Configuration.shared.vmImagesRegion
        let bucket = Configuration.shared.vmImagesBucket

        /// Create the parent directory if it doesn't already exist
        let parentDirectory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        try S3Manager().streamingDownloadFile(
            region: region,
            bucket: bucket,
            key: image.imageObject.key,
            destination: destination,
            progressCallback: progressCallback
        )
    }

    func list(prefix: String = "images/") throws -> [RemoteImage] {

        let objects = try S3Manager().listObjects(region: region, bucket: bucket, startingWith: prefix)

        let imageObjects = objects
            .compactMap(self.convertToNewS3Object)
            .filter { $0.key.hasSuffix(".pvmp") }

        let checksums = objects
            .compactMap(self.convertToNewS3Object)
            .filter { $0.key.hasSuffix(".sha256.txt") }
            .map(\.key)

        return imageObjects.compactMap { object in
            let filename = URL(fileURLWithPath: object.key).lastPathComponent  // filename = my-image.pvmp
            let basename = (filename as NSString).deletingPathExtension        // basename = my-image

            let checksumObject = S3Object(key: "images/" + basename + ".sha256.txt")

            guard checksums.contains(checksumObject.key) else {
                return nil
            }

            return RemoteImage(imageObject: object, checksumObject: checksumObject)
        }
    }

    private func convertToNewS3Object(_ oldS3Object: S3.Object) -> S3Object? {
        guard
            let key = oldS3Object.key,
            let size = oldS3Object.size
        else {
            return nil
        }

        return S3Object(key: key, size: Int(size))
    }
}
