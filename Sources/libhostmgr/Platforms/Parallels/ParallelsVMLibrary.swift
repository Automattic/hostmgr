import Foundation
import tinys3

public struct ParallelsVMLibrary: RemoteVMLibrary {
    public typealias VM = ParallelsRemoteVMImage

    /// Downloads a remote image using atomic writes to avoid conflict with existing files or other processes
    ///
    @discardableResult
    public func download(image: VM, progressCallback: @escaping ProgressCallback) async throws -> URL {

        // Download the checksum file first
       try await self.s3Manager.download(
            key: image.checksumPath,
            to: Paths.vmWorkingStorageDirectory.appendingPathComponent(image.checksumFileName),
            replacingExistingFile: false,
            progressCallback: nil)

        let imageFileDestination = Paths.vmWorkingStorageDirectory.appendingPathComponent(image.fileName)

        try await self.s3Manager.download(
            key: image.path,
            to: imageFileDestination,
            replacingExistingFile: false,
            progressCallback: progressCallback
        )

        return imageFileDestination
    }

    var s3Manager: S3Manager {
        get throws {
            try S3Manager(
                bucket: Configuration.shared.vmImagesBucket,
                region: Configuration.shared.vmImagesRegion,
                credentials: try AWSCredentials.fromUserConfiguration(),
                endpoint: Configuration.shared.vmImagesEndpoint
            )
        }
    }
}
