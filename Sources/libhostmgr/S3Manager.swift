import Foundation
import Alamofire
import SotoS3

public typealias FileTransferProgressCallback = (FileTransferProgress) -> Void

public protocol S3ManagerProtocol {
    func listObjects(startingWith prefix: String?) async throws -> [S3Object]
    func lookupObject(atPath path: String) async throws -> S3Object?
    func download(
        object: S3Object,
        to destination: URL,
        progressCallback: FileTransferProgressCallback?
    ) async throws

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

    public func download(
        object: S3Object,
        to destination: URL,
        progressCallback: FileTransferProgressCallback?
    ) async throws {

        let signedURL = try await presignedUrl(forObject: object)

        let destinationResolver: DownloadRequest.Destination = { _, _ in
            return (FileManager.default.temporaryFilePath(), [.createIntermediateDirectories, .removePreviousFile])
        }

        let temporaryFile = try await AF
            .download(signedURL, method: .get, to: destinationResolver)
            .downloadProgress { progressCallback?(.progressData(from: $0)) }
            .serializingDownloadedFileURL(automaticallyCancelling: true)
            .value

        _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporaryFile)
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

public struct FileTransferProgress {
    public typealias Percentage = Decimal

    let current: Int
    let total: Int

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var percent: Percentage {
        Decimal(Double(self.current) / Double(self.total) * 100.0)
    }

    public var downloadedData: String {
        ByteCountFormatter.string(fromByteCount: Int64(current), countStyle: .file)
    }

    public var totalData: String {
        ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    public func dataRate(timeIntervalSinceStart interval: TimeInterval) -> String {
        let bytesPerSecond = Double(current) / interval

        // Don't continue unless the rate can be represented by `Int64`
        guard bytesPerSecond.isNormal else {
            return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
        }

        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
    }

    public func estimatedTimeRemaining(timeIntervalSinceStart interval: TimeInterval) -> TimeInterval {
        let bytesPerSecond = Double(current) / interval

        // Don't continue unless the rate makes some kind of sense
        guard bytesPerSecond.isNormal else {
            return .infinity
        }

        let totalNumberOfSeconds = Double(total) / bytesPerSecond

        return totalNumberOfSeconds - interval
    }

    public var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.alwaysShowsDecimalSeparator = true
        formatter.roundingMode = .down
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: percent as NSDecimalNumber)!
    }

    static func progressData(from progress: Progress) -> FileTransferProgress {
        return FileTransferProgress(
            current: Int(progress.completedUnitCount),
            total: Int(progress.totalUnitCount)
        )
    }
}
