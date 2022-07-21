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
        let imageKey: String
        let checksumKey: String
        let size: Int64

        var imagePath: String {
            imageKey
        }

        var fileName: String {
            (imageKey as NSString).lastPathComponent
        }

        var basename: String {
            (fileName as NSString).deletingPathExtension
        }

        init(imageKey: String, checksumKey: String, size: Int64) {
            self.imageKey = imageKey
            self.checksumKey = checksumKey
            self.size = size
        }
    }

    private let region = Configuration.shared.vmImagesRegion
    private let bucket = Configuration.shared.vmImagesBucket

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

        debugPrint(basename, objects)

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

        return RemoteImage(imageKey: imageObjectKey, checksumKey: checksumObjectKey, size: imageObjectSize)
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
            key: image.imageKey,
            destination: destination,
            progressCallback: progressCallback
        )
    }

    func list(prefix: String = "images/") throws -> [RemoteImage] {

        let objects = try S3Manager().listObjects(region: region, bucket: bucket, startingWith: prefix)

        let images = objects.filter { $0.key?.hasSuffix(".pvmp") ?? false }
        let checksums = objects.filter { $0.key?.hasSuffix(".sha256.txt") ?? false }

        return images
            .compactMap { $0.key }
            .compactMap { key -> RemoteImage? in                                 // key = /images/my-image.pvmp
                let filename = URL(fileURLWithPath: key).lastPathComponent  // filename = my-image.pvmp
                let basename = (filename as NSString).deletingPathExtension         // basename = my-image

                guard
                    let checksum = checksums.first(where: { $0.key?.contains(basename) ?? false })?.key,
                    let size = images.first(where: { $0.key == key })?.size
                else {
                    return nil
                }

                return RemoteImage(imageKey: key, checksumKey: checksum, size: size)
            }
    }
}
