import Foundation
import tinys3

public struct S3Server: RemoteFileProvider {
    private let bucketName: String
    private let endpoint: S3Endpoint

    public static let gitMirrors: S3Server = S3Server(
        bucketName: Configuration.shared.gitMirrorBucket,
        endpoint: Configuration.shared.gitMirrorEndpoint
    )

    public static let secrets: S3Server = S3Server(
        bucketName: Configuration.shared.authorizedKeysBucket,
        endpoint: .default
    )

    public static let vmImages: S3Server = S3Server(
        bucketName: Configuration.shared.vmImagesBucket,
        endpoint: .accelerated
    )

    public init(bucketName: String, endpoint: S3Endpoint) {
        self.bucketName = bucketName
        self.endpoint = endpoint
    }

    public func listFiles(startingWith prefix: String) async throws -> [RemoteFile] {
        try await s3Client.list(bucket: bucketName, prefix: prefix).objects.map(self.convert)
    }

    public func hasFile(at path: String) async throws -> Bool {
        try await listFiles(startingWith: path).isEmpty
    }

    var s3Client: S3Client {
        get throws {
            S3Client(credentials: try .fromUserConfiguration(), endpoint: self.endpoint)
        }
    }

    func convert(_ s3Object: S3Object) -> RemoteFile {
        RemoteFile(size: s3Object.size, path: s3Object.key, lastModifiedAt: s3Object.lastModifiedAt)
    }
}

extension S3Server: ReadableRemoteFileProvider {
    public func downloadFile(at path: String, to destination: URL, progress: @escaping ProgressCallback) async throws {
        let tempUrl = try await s3Client.download(
            objectWithKey: path,
            inBucket: self.bucketName,
            progressCallback: progress
        )

        if FileManager.default.fileExists(at: destination) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: tempUrl, to: destination)
    }
}

extension S3Server: WritableRemoteFileProvider {

    public func uploadFile(at source: URL, to destination: String, progress: @escaping ProgressCallback) async throws {
        try await s3Client.upload(
            objectAtPath: source,
            toBucket: self.bucketName,
            key: destination,
            progressCallback: progress
        )
    }
}
