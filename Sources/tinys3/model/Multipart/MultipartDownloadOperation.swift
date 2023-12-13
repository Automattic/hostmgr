import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class MultipartDownloadOperation: NSObject, RequestPerformer {
    let bucket: String
    let key: String

    let credentials: AWSCredentials
    let endpoint: S3Endpoint

    let urlSession: URLSession

    var progressCallback: ProgressCallback?
    var progress: Progress!
    var startDate: Date!

    init(
        bucket: String,
        key: String,
        credentials: AWSCredentials,
        endpoint: S3Endpoint = .default,
        urlSession: URLSession = .shared
    ) {
        self.bucket = bucket
        self.key = key

        self.credentials = credentials
        self.endpoint = endpoint

        self.urlSession = urlSession
    }

    func start(
        downloadingTo path: URL,
        progress callback: ProgressCallback? = nil,
        workingDirectory: URL = FileManager.default.temporaryDirectory
    ) async throws {
        self.startDate = Date()
        self.progressCallback = callback

        let objectDetails = try await self.fetchObjectDetails()

        let partsToDownload = MultipartDownloadFile(
            object: objectDetails,
            workingDirectory: workingDirectory
        ).parts

        self.progress = Progress(totalUnitCount: Int64(partsToDownload.count * 10) + Int64(partsToDownload.count))

        let partPaths = try await partsToDownload.parallelMap(parallelism: 8) { try await self.downloadPart($0) }

        try self.combine(parts: partPaths, at: path)
    }

    func downloadPart(_ part: MultipartDownloadFile.DownloadPart) async throws -> URL {

        // If the part already exists, there's no need to re-download it – we can save some work
        guard try !part.alreadyExists() else {
            bumpProgress(for: .download)
            return part.tempFilePath
        }

        let downloadRequest = AWSRequest.downloadRequest(
            bucket: self.bucket,
            key: self.key,
            range: part.range,
            credentials: self.credentials,
            endpoint: self.endpoint
        )

        let response = try await perform(downloadRequest).validate()
        self.bumpProgress(for: .download)
        return try writeDownloadedPart(part, data: response.data)
    }

    func writeDownloadedPart(_ part: MultipartDownloadFile.DownloadPart, data: Data) throws -> URL {
        try data.write(to: part.tempFilePath)
        return part.tempFilePath
    }

    func combine(parts: [URL], at url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: url)

        for part in parts {
            let data = try Data(contentsOf: part)
            fileHandle.write(data)
            bumpProgress(for: .combination)
        }

        try fileHandle.close()
    }

    /// Different kinds of progress have different weights for how they affect the total completion percentage
    ///
    enum ProgressKind: Int64 {
        case combination = 1
        case download = 10
    }

    func bumpProgress(for kind: ProgressKind) {
        self.progress.completedUnitCount += kind.rawValue
        self.progressCallback?(self.progress)
    }

    func fetchObjectDetails() async throws -> S3Object {
        let request = AWSRequest.headRequest(bucket: self.bucket, key: self.key, credentials: self.credentials)
        let response = try await perform(request).validate()

        guard let s3Object = S3HeadResponse.from(key: key, response: response).s3Object else {
            throw S3Error.fileNotFound(self.bucket, self.key)
        }

        return s3Object
    }
}
