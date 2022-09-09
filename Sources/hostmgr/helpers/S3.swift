import Foundation
import ArgumentParser
import SotoS3
import libhostmgr

struct S3Manager {

    func listObjects(region: Region, bucket: String, startingWith prefix: String) throws -> [S3.Object] {

        let awsClient = getAWSClient()

        defer {
            try? awsClient.syncShutdown()
        }

        let s3Client = S3(client: awsClient, region: region)

        let request = S3.ListObjectsV2Request(
            bucket: bucket,
            maxKeys: 1000,
            prefix: prefix
        )

        let result = try s3Client.listObjectsV2(request).wait()
        return result.contents ?? []
    }

    func getFileBytes(region: Region, bucket: String, key: String) throws -> Data? {
        let awsClient = getAWSClient()

        defer {
            try? awsClient.syncShutdown()
        }

        let s3Client = S3(client: awsClient, region: region)

        let request = S3.GetObjectRequest(
            bucket: bucket,
            key: key
        )

        let result = try s3Client.getObject(request).wait()

        return result.body?.asData()
    }

    func getFileSize(region: Region, bucket: String, key: String) throws -> Int64 {
        try listObjects(region: region, bucket: bucket, startingWith: key).first?.size ?? 0
    }

    func streamingDownloadFile(
        region: Region,
        bucket: String,
        key: String,
        destination: URL,
        progressCallback: FileTransferProgressCallback? = nil
    ) throws {

        let client = getAWSClient()

        defer {
            try? client.syncShutdown()
        }

        // Create the parent directory if needed
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        FileManager.default.createFile(atPath: destination.path, contents: nil)

        let handle = try getFileHandle(to: destination)

        defer {
            try? handle.close()
        }

        var downloadedBytes = 0
        let totalBytes = try getFileSize(region: region, bucket: bucket, key: key)

        // Estimate the time to download the file under 10 MB/s download speed
        let totalMB = Int64(Measurement<UnitInformationStorage>(value: Double(totalBytes), unit: .bytes).converted(to: .megabytes).value)
        let timeout = totalMB / 10
        logger.info("Download timeout: \(timeout / 60) minutes")

        let s3Client = try getS3Client(from: client, for: bucket, in: region).with(timeout: .seconds(timeout))
        let objectRequest = S3.GetObjectRequest(bucket: bucket, key: key)

        _ = try s3Client.getObjectStreaming(objectRequest, logger: logger) { buffer, loop in
            let availableBytes = buffer.readableBytes
            downloadedBytes += availableBytes
            if let bytes = buffer.getData(at: buffer.readerIndex, length: availableBytes) {
                handle.write(bytes)
            }
            progressCallback?(availableBytes, downloadedBytes, totalBytes)
            return loop.makeSucceededVoidFuture()
        }.wait()
    }

    private func getFileHandle(to destination: URL) throws -> FileHandle {
        do {
            return try FileHandle(forWritingTo: destination)
        } catch let err {
            print("Unable write to \(destination): \(err.localizedDescription)")
            throw err
        }
    }

    private func getAWSClient() -> AWSClient {

        var credentialProvider: CredentialProviderFactory

        print("Using \(Configuration.shared.awsConfigurationMethod!) to connect to AWS")

        switch Configuration.shared.awsConfigurationMethod {
        case .configurationFile:credentialProvider = .configFile()
        case .ec2Environment: credentialProvider = .ec2
        case .none: credentialProvider = .configFile()
        }

        return AWSClient(
            credentialProvider: credentialProvider,
            httpClientProvider: .createNew
        )
    }

    private func getS3Client(
        from aws: AWSClient,
        for bucket: String,
        in region: Region
    ) throws -> S3 {
        let s3Client = S3(client: aws, region: region)

        guard Configuration.shared.allowAWSAcceleratedTransfer else {
            logger.log(level: .info, "Using Standard S3 Download")
            return s3Client
        }

        guard try bucketTransferAccelerationIsEnabled(for: bucket, in: region) else {
            logger.log(level: .info, "Using Standard S3 Download")
            return s3Client
        }

        logger.log(level: .info, "Using Accelerated S3 Download")

        return S3(
            client: aws,
            region: region,
            endpoint: "https://\(bucket).s3-accelerate.amazonaws.com"
        )
    }

    private func bucketTransferAccelerationIsEnabled(for bucket: String, in region: Region) throws -> Bool {
        let client = getAWSClient()

        defer {
            try? client.syncShutdown()
        }

        let bucketInfoRequest = S3.GetBucketAccelerateConfigurationRequest(bucket: bucket)
        return try S3(client: client, region: region)
            .getBucketAccelerateConfiguration(bucketInfoRequest, logger: logger)
            .wait()
            .status == .enabled
    }
}

extension Region: ExpressibleByArgument {}

typealias FileTransferProgressCallback = (Int, Int, Int64) -> Void
