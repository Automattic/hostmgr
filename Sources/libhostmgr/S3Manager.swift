import Foundation
import Alamofire
import SotoS3

public typealias FileTransferProgressCallback = (Progress) -> Void

public protocol S3ManagerProtocol {
    func listObjects(startingWith prefix: String?) async throws -> [S3Object]
    func lookupObject(atPath path: String) async throws -> S3Object?
    @discardableResult func download(
        object: S3Object,
        to destination: URL,
        progressCallback: FileTransferProgressCallback?
    ) async throws -> URL

    func download(object: S3Object) async throws -> Data?
}

public struct S3Manager: S3ManagerProtocol {

    private let bucket: String
    private let region: String

    public init(bucket: String, region: String) {
        self.bucket = bucket
        self.region = region
    }

    public func listObjects(startingWith prefix: String? = nil) async throws -> [S3Object] {
        try await withS3Client {
            let request = SotoS3.S3.ListObjectsV2Request(
                bucket: self.bucket,
                maxKeys: 1000,
                prefix: prefix
            )

            let response = try await $0.listObjectsV2(request)
            guard let objects = response.contents else {
                return []
            }

            return objects.compactMap { $0.toS3Object }
        }
    }

    public func lookupObject(atPath path: String) async throws -> S3Object? {
        try await withS3Client {
            let request =  SotoS3.S3.HeadObjectRequest(bucket: bucket, key: path)
            let result = try await $0.headObject(request)
            return S3Object(key: path, size: Int(result.contentLength!))
        }
    }

    @discardableResult
    public func download(
        object: S3Object,
        to destination: URL,
        progressCallback: FileTransferProgressCallback?
    ) async throws -> URL {

        let signedURL = try await presignedUrl(forObject: object)

        let destinationResolver: DownloadRequest.Destination = { _, _ in
            return (FileManager.default.temporaryFilePath(), [.createIntermediateDirectories, .removePreviousFile])
        }

        return try await AF
            .download(signedURL, method: .get, to: destinationResolver)
            .downloadProgress { progressCallback?($0) }
            .serializingDownloadedFileURL(automaticallyCancelling: true)
            .value
    }

    public func download(object: S3Object) async throws -> Data? {
        let signedURL = try await presignedUrl(forObject: object)
        return await AF.request(signedURL, method: .get)
            .validate()
            .serializingData()
            .response
            .value
    }

    private func presignedUrl(forObject object: S3Object) async throws -> URL {
        try await withS3Client {
            var unsignedUrl = URL(string: "https://\(bucket).s3.\(region).amazonaws.com/\(object.key)")!

            if try await bucketSupportsAcceleratedDownload {
                unsignedUrl = URL(string: "https://\(bucket).s3-accelerate.amazonaws.com/\(object.key)")!
            }

            return try await $0.signURL(
                url: unsignedUrl,
                httpMethod: .GET,
                expires: .hours(24)
            )
        }
    }

    private var bucketSupportsAcceleratedDownload: Bool {
        get async throws {
            try await withS3Client {
                let request = SotoS3.S3.GetBucketAccelerateConfigurationRequest(bucket: self.bucket)
                let response = try await $0.getBucketAccelerateConfiguration(request)
                return response.status == .enabled
            }
        }
    }

    private func withS3Client<T>(_ block: (SotoS3.S3) async throws -> T) async throws -> T {
        let awsClient = AWSClient(credentialProvider: credentialProvider, httpClientProvider: .createNew)
        let s3Client = SotoS3.S3(client: awsClient, region: Region(rawValue: self.region))

        // The following code `try await` the given operation to execute with a
        // `SotoS3.S3` client created ad hoc and, once done, shuts down that
        // client.
        //
        // If something goes wrong while running the block, we still need to
        // shutdown the client, else the error from the block will be lost and
        // the program will fail with something like:
        //
        // SotoCore/AWSClient.swift:110: Assertion failed:
        //   AWSClient not shut down before the deinit.
        //   Please call client.syncShutdown() when no longer needed.
        //
        // It would be good to use `defer`, but it doesn't yet support asycn.
        // See https://forums.swift.org/t/async-rethrows-and-defer/58356.
        //
        // So, we use a `do catch` where in the catch we first shutdown the
        // client and then bubble up the error.
        let result: T
        do {
            result = try await block(s3Client)
        } catch {
            try await awsClient.shutdown()
            throw error
        }

        // We need to shutdown the client also when `block` run successfully.
        //
        // This duplication with the call above will disappear once Swift will
        // give us a way to call `defer`.
        try await awsClient.shutdown()

        return result
    }

    private var credentialProvider: CredentialProviderFactory {
        switch Configuration.shared.awsConfigurationMethod {
        case .configurationFile: return .configFile()
        case .ec2Environment: return .ec2
        case .none: return .configFile()
        }
    }
}

extension SotoS3.S3.Object {
    var toS3Object: S3Object? {
        guard
            let key = self.key,
            let size = self.size
        else { return nil }

        return S3Object(key: key, size: Int(size))
    }
}

public struct S3Object {
    public let key: String
    public let size: Int

    public init(key: String, size: Int) {
        self.key = key
        self.size = size
    }
}
