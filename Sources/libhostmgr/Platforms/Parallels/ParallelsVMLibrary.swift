import Foundation
import tinys3

public struct ParallelsVMLibrary: RemoteVMLibrary {

    public typealias VM = ParallelsRemoteVMImage

    public let s3Manager: S3ManagerProtocol

    public init() throws {
        let bucket: String = Configuration.shared.vmImagesBucket
        let region: String = Configuration.shared.vmImagesRegion
        let credentials = try AWSCredentials.fromUserConfiguration()

        self.s3Manager = try S3Manager(
            bucket: bucket,
            region: region,
            credentials: credentials,
            endpoint: .accelerated
        )
    }

    /// Downloads a remote image using atomic writes to avoid conflict with existing files or other processes
    ///
    @discardableResult
    public func download(
        image: ParallelsRemoteVMImage,
        destinationDirectory: URL,
        progressCallback: @escaping FileTransferProgressCallback
    ) async throws -> URL {

        // Download the checksum file first
       try await self.s3Manager.download(
            key: image.checksumPath,
            to: destinationDirectory.appendingPathComponent(image.checksumFileName),
            replacingExistingFile: false,
            progressCallback: nil)

        let imageFileDestination = destinationDirectory.appendingPathComponent(image.fileName)

        try await self.s3Manager.download(
            key: image.path,
            to: destinationDirectory.appendingPathComponent(image.fileName),
            replacingExistingFile: false,
            progressCallback: progressCallback
        )

        return imageFileDestination
    }
}
