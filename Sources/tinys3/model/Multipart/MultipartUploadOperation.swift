import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class MultipartUploadOperation: NSObject, RequestPerformer {
    let bucket: String
    let key: String
    let path: URL
    let credentials: AWSCredentials
    let endpoint: S3Endpoint

    let urlSession: URLSession = .shared

    struct AWSPartData {
        let uploadId: String
        let number: Int
        let data: Data

        init(uploadId: String, number: Int, data: Data) {
            self.uploadId = uploadId
            self.number = number
            self.data = data
        }

        var sha256Hash: String {
            tinys3.sha256Hash(data: data)
        }
    }

    struct AWSUploadedPart: Comparable {
        let number: Int
        let eTag: String

        static func < (
            lhs: MultipartUploadOperation.AWSUploadedPart,
            rhs: MultipartUploadOperation.AWSUploadedPart
        ) -> Bool {
            lhs.number < rhs.number
        }
    }

    private let file: MultipartUploadFile

    private var progress: Progress
    private var progressCallback: ProgressCallback?
    private var startDate: Date!

    init(bucket: String, key: String, path: URL, credentials: AWSCredentials, endpoint: S3Endpoint = .default) throws {
        self.bucket = bucket
        self.key = key
        self.path = path
        self.credentials = credentials
        self.endpoint = endpoint

        self.file = try MultipartUploadFile(path: path)
        self.progress = Progress.from(self.file.fileSize)
    }

    func start(_ progressCallback: ProgressCallback? = nil) async throws {
        self.startDate = Date()
        self.progressCallback = progressCallback

        let createRequest = AWSRequest.createMultipartUploadRequest(
            bucket: bucket,
            key: key,
            path: path,
            credentials: self.credentials
        )

        let createResponse = try S3CreateMultipartUploadResponse.from(response: await perform(createRequest).validate())

        let uploadId = createResponse.uploadId

        let uploadedParts = try await file.uploadParts.parallelMap(parallelism: 8) {
           try await self.uploadPart(withUploadId: uploadId, forRange: $0.1, atIndex: $0.0)
        }

        let builder = S3MultipartUploadCompleteXMLBuilder().addParts(uploadedParts)

        let finalizeRequest = AWSRequest.completeMultipartUploadRequest(
            bucket: bucket,
            key: key,
            uploadId: uploadId,
            data: builder.build(),
            credentials: self.credentials
        )

        try await perform(finalizeRequest).validate()
    }

    func uploadPart(
        withUploadId uploadId: String,
        forRange range: Range<Int>,
        atIndex index: Int
    ) async throws -> AWSUploadedPart {

        let part = AWSPartData(
            uploadId: uploadId,
            number: index,
            data: try await file[range]
        )

        let request = try AWSRequest.uploadPartRequest(
            bucket: bucket,
            key: key,
            part: part,
            credentials: self.credentials,
            endpoint: self.endpoint
        )

        if #available(macOS 12.0, *) {
            let response = try await upload(request).validate()

            guard let eTag = response.value(forHTTPHeaderField: .eTag) else {
                throw CocoaError(.propertyListReadUnknownVersion)
            }

            return AWSUploadedPart(number: part.number, eTag: eTag)
        } else {
            let response = try await perform(request).validate()

            self.progress.completedUnitCount += Int64(part.data.count)
            self.progress.estimateThroughput(fromStartDate: self.startDate)
            self.progressCallback?(self.progress)

            guard let eTag = response.value(forHTTPHeaderField: .eTag) else {
                throw CocoaError(.propertyListReadUnknownVersion)
            }

            return AWSUploadedPart(number: part.number, eTag: eTag)
        }
    }

    @available(macOS 12.0, *)
    func upload(_ request: AWSRequest) async throws -> AWSResponse {
        var urlRequest = request.urlRequest
        urlRequest.timeoutInterval = 3600

        let (data, response) = try await URLSession.shared.data(for: urlRequest, delegate: self)
        return try AWSResponse(response: response as? HTTPURLResponse, data: data)
    }
}

extension MultipartUploadOperation: URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        self.progress.completedUnitCount += bytesSent
        self.progress.estimateThroughput(fromStartDate: self.startDate)
        self.progressCallback?(self.progress)
    }
}

extension Collection {
    func parallelMap<T>(parallelism: Int, _ transform: @escaping (Element) async throws -> T) async throws -> [T] {

        let elementCount = self.count

        if elementCount == 0 {
            return []
        }

        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var result = [T?](repeatElement(nil, count: elementCount))

            var index = self.startIndex
            var submitted = 0

            func submitNext() async throws {
                if index == self.endIndex { return }

                group.addTask { [submitted, index] in
                    let value = try await transform(self[index])
                    return (submitted, value)
                }

                submitted += 1
                formIndex(after: &index)
            }

            // submit first initial tasks
            for _ in 0..<parallelism {
                try await submitNext()
            }

            // as each task completes, submit a new task until we run out of work
            while let (index, taskResult) = try await group.next() {
                result[index] = taskResult

                try Task.checkCancellation()
                try await submitNext()
            }

            assert(result.count == elementCount)
            return Array(result.compactMap { $0 })
        }
    }
}
