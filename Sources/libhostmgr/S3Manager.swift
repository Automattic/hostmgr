import Foundation
import CryptoKit
import tinys3

public typealias FileTransferProgressCallback = (Progress) -> Void
public typealias HeaderCallback = ([String: String]) -> Void
public typealias DataCallback = (Data) -> Void

public protocol S3ManagerProtocol {
    func listObjects(startingWith prefix: String?) async throws -> [S3Object]
    func lookupObject(atPath path: String) async throws -> S3Object?
    func download(
        key: String,
        to destination: URL,
        progressCallback: FileTransferProgressCallback?
    ) async throws

    func download(object: S3Object) async throws -> Data?
}

public struct S3Manager: S3ManagerProtocol {

    private let bucket: String
    private let region: String

    public let s3Client: S3Client

    public init(bucket: String, region: String, credentials: AWSCredentials, endpoint: S3Endpoint) throws {
        self.bucket = bucket
        self.region = region
        self.s3Client = S3Client(credentials: credentials, endpoint: endpoint)
    }

    public func listObjects(startingWith prefix: String? = nil) async throws -> [S3Object] {
        try await s3Client.list(bucket: self.bucket, prefix: prefix ?? "").objects
    }

    public func lookupObject(atPath path: String) async throws -> S3Object? {
        try await s3Client.head(bucket: self.bucket, key: path).s3Object
    }

    public func download(
        key: String,
        to destination: URL,
        progressCallback: FileTransferProgressCallback?
    ) async throws {
        let tempUrl = try await s3Client.download(
            objectWithKey: key,
            inBucket: self.bucket,
            progressCallback: progressCallback
        )
        try FileManager.default.moveItem(at: tempUrl, to: destination)
    }

    public func download(object: S3Object) async throws -> Data? {
        let tempURL = try await s3Client.download(objectWithKey: object.key, inBucket: self.bucket)
        return try Data(contentsOf: tempURL)
    }

    public func stream(
        object: S3Object,
        headersCallback: @escaping HeaderCallback,
        dataCallback: @escaping DataCallback,
        progressCallback: ProgressCallback?
    ) async throws -> URL {
        try await s3Client.stream(
            objectWithKey: object.key,
            inBucket: self.bucket,
            progressCallback: progressCallback,
            headersCallback: headersCallback,
            dataCallback: dataCallback
        )
    }
}
