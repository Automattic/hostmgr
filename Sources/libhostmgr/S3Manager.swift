import Foundation
import CryptoKit
import tinys3

public struct S3Manager {

    enum Errors: Error {
        case fileExistsAtDestination
    }

    private let bucket: String
    private let s3Client: tinys3.S3Client

    public init(bucket: String, credentials: tinys3.AWSCredentials, endpoint: S3Endpoint) throws {
        self.bucket = bucket
        self.s3Client = S3Client(credentials: credentials, endpoint: endpoint)
    }

    public func listObjects(startingWith prefix: String = "") async throws -> [S3Object] {
        try await s3Client.list(bucket: self.bucket, prefix: prefix).objects
    }

    public func lookupObject(atPath path: String) async throws -> S3Object? {
        try await listObjects(startingWith: path).first
    }

    public func download(
        key: String,
        to destination: URL,
        replacingExistingFile shouldReplaceExistingFile: Bool = true,
        progressCallback: ProgressCallback?
    ) async throws {

        let tempUrl = try await s3Client.download(
            objectWithKey: key,
            inBucket: self.bucket,
            progressCallback: progressCallback
        )

        if FileManager.default.fileExists(at: destination) {
            if shouldReplaceExistingFile {
                try FileManager.default.removeItem(at: destination)
            } else {
                throw Errors.fileExistsAtDestination
            }
        }

        try FileManager.default.moveItem(at: tempUrl, to: destination)
    }

    public func download(object: S3Object) async throws -> Data? {
        let downloadUrl = s3Client.signedDownloadUrl(forKey: object.key, in: self.bucket, validFor: 60)
        return try await URLSession.shared.data(from: downloadUrl).0
    }

    public func upload(fileAt path: URL, toKey key: String, progress: ProgressCallback? = nil) async throws {
        try await s3Client.upload(objectAtPath: path, toBucket: self.bucket, key: key, progressCallback: progress)
    }
}
