import Foundation
import tinys3

public struct S3Server: ReadWriteRemoteFileProvider, BytewiseRemoteFileProvider {
    private let bucketName: String
    private let region: String
    private let endpoint: S3Endpoint

    enum Errors: Error {
        case fileNotFound
        case unableToReadFile
    }

    struct File: RemoteFile {
        let name: String
        let size: Int
        let path: String

        static func < (lhs: S3Server.File, rhs: S3Server.File) -> Bool {
            lhs.name < rhs.name
        }
    }

    public static let gitMirrors: S3Server = S3Server(
        bucketName: Configuration.shared.gitMirrorBucket,
        region: Configuration.shared.gitMirrorRegion,
        endpoint: Configuration.shared.gitMirrorEndpoint
    )

    public static let secrets: S3Server = S3Server(
        bucketName: Configuration.shared.authorizedKeysBucket,
        region: Configuration.shared.authorizedKeysRegion,
        endpoint: .default
    )

    public static let vmImages: S3Server = S3Server(
        bucketName: Configuration.shared.vmImagesBucket,
        region: Configuration.shared.vmImagesRegion,
        endpoint: Configuration.shared.vmImagesEndpoint
    )

    public init(bucketName: String, region: String, endpoint: S3Endpoint) {
        self.bucketName = bucketName
        self.region = region
        self.endpoint = endpoint
    }

    public func uploadFile(at source: URL, to destination: String, progress: @escaping ProgressCallback) async throws {
        try await s3Client.upload(fileAt: source, toKey: destination, progress: progress)
    }

    public func downloadFile(at path: String, to destination: URL, progress: @escaping ProgressCallback) async throws {
        try await s3Client.download(key: path, to: destination, progressCallback: progress)
    }

    func fetchFileBytes(forFileAt path: String) async throws -> Data {
        guard let object = try await s3Client.lookupObject(atPath: path) else {
            throw Errors.fileNotFound
        }

        guard let bytes = try await s3Client.download(object: object) else {
            throw Errors.unableToReadFile
        }

        return bytes
    }

    public func listFiles(startingWith prefix: String) async throws -> [any RemoteFile] {
        try await s3Client.listObjects(startingWith: prefix).compactMap {
            guard let name = $0.key.split(separator: "/").last else {
                return nil
            }

            return File(name: String(name), size: $0.size, path: $0.key)
        }
    }

    public func hasFile(at path: String) async throws -> Bool {
        try await !s3Client.listObjects(startingWith: path).isEmpty
    }

    var s3Client: S3Manager {
        get throws {
            try S3Manager(
                bucket: self.bucketName,
                region: self.region,
                credentials: .fromUserConfiguration(),
                endpoint: self.endpoint
            )
        }
    }
}
