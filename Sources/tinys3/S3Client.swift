import Foundation
import Crypto

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(OSLog)
import OSLog
#endif

public struct S3Client: RequestPerformer {

    private let credentials: AWSCredentials
    private let endpoint: S3Endpoint
    let urlSession: URLSession

    public init(credentials: AWSCredentials, endpoint: S3Endpoint = .default, urlSession: URLSession = .shared) {
        self.credentials = credentials
        self.endpoint = endpoint
        self.urlSession = urlSession

        #if canImport(OSLog)
        if #available(macOS 11.0, *) {
            Logger(OSLog.default).info("Created S3 Client")
            Logger(OSLog.default).info("S3 Client Access Key ID: \(credentials.accessKeyId, privacy: .public)")
            Logger(OSLog.default).info("S3 Client Secret Key: \(credentials.secretKey, privacy: .private)")
            Logger(OSLog.default).info("S3 Client Region: \(credentials.region, privacy: .public)")
        }
        #endif
    }

    public func head(bucket: String, key: String) async throws -> S3Object? {
        let request = AWSRequest.headRequest(
            bucket: bucket,
            key: key,
            credentials: self.credentials
        )

        let response = try await perform(request).validate()
        return S3HeadResponse.from(key: key, response: response).s3Object
    }

    public func list(bucket: String, prefix: String = "") async throws -> S3ListResponse {
        let request = AWSRequest.listRequest(
            bucket: bucket,
            prefix: prefix,
            credentials: self.credentials
        )

        let response = try await perform(request).validate()
        return try S3ListResponse.from(response: response)
    }

    public func signedDownloadUrl(forKey key: String, in bucket: String, validFor timeInterval: TimeInterval) -> URL {
        AWSPresignedDownloadURL(
            bucket: bucket,
            key: key,
            ttl: timeInterval,
            credentials: self.credentials
        ).url
    }

    /// Downloads a file from S3
    ///
    /// The file is downloaded in pieces, so resume is automatically available for large files.
    ///
    /// - Parameters:
    ///     - objectWithKey: The object stored at the given key.
    ///     - inBucket: The bucket containing the object for download
    ///     - progressCallback: Used to monitor the progress of the download operation
    ///     - chunkSize: The chunk size to use – this controls both the number of files that
    ///     will be created on-disk for a given download – a larger file will have many chunks at
    ///     the default sizes. This also controls the amount of memory that'll be
    ///     used – chunks are buffered in RAM, so larger chunks sizes will cause higher memory use.
    ///     - workingDirectory: The location on-disk for chunks to be stored after they're 
    ///     downloaded but before they're re-combined. Defaults to the system temp directory.
    ///
    /// - Returns: A `URL` pointing to the downloaded file on-disk

    public func download(
        objectWithKey key: String,
        inBucket bucket: String,
        progressCallback: ProgressCallback? = nil,
        chunkSize: MultipartDownloadFile.ChunkSize = .default,
        workingDirectory: URL = FileManager.default.temporaryDirectory
    ) async throws -> URL {
        let destination = FileManager.default.temporaryFile
        try await MultipartDownloadOperation(
            bucket: bucket,
            key: key,
            credentials: self.credentials,
            endpoint: self.endpoint
        ).start(downloadingTo: destination, progress: progressCallback)
        return destination
    }

    public func upload(
        objectAtPath path: URL,
        toBucket bucket: String,
        key: String,
        progressCallback: ProgressCallback? = nil
    ) async throws {
        let operation = try MultipartUploadOperation(
            bucket: bucket,
            key: key,
            path: path,
            credentials: self.credentials
        )

        try await operation.start(progressCallback)
    }
}
