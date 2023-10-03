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

    public func listFiles(startingWith prefix: String) async throws -> [RemoteFile] {
        try await s3Client.listObjects(startingWith: prefix).map { $0.asFile }
    }

    public func hasFile(at path: String) async throws -> Bool {
        try await !s3Client.listObjects(startingWith: path).isEmpty
    }

    public func fileDetails(forPath path: String) async throws -> RemoteFile? {
        try await s3Client.lookupObject(atPath: path)?.asFile
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

extension S3Object {
    var asFile: RemoteFile {
        RemoteFile(size: size, path: key, lastModifiedAt: lastModifiedAt)
    }
}
