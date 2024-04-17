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
    let allowResume: Bool

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

    init(
        bucket: String,
        key: String,
        path: URL,
        credentials: AWSCredentials,
        endpoint: S3Endpoint = .default,
        allowResume: Bool
    ) throws {
        self.bucket = bucket
        self.key = key
        self.path = path
        self.credentials = credentials
        self.endpoint = endpoint
        self.allowResume = allowResume

        self.file = try MultipartUploadFile(path: path)
        self.progress = Progress.from(self.file.fileSize)
    }

    func start(_ progressCallback: ProgressCallback? = nil) async throws {
        self.startDate = Date()
        self.progressCallback = progressCallback

        let uploadId: String
        let alreadyUploadedParts: [AWSUploadedPart]

        // Check if pending upload requests matching the file to be uploaded
        if self.allowResume, let existingPartsResponse = try await findMostRecentUncompletedParts() {
            alreadyUploadedParts = existingPartsResponse.parts
            uploadId = existingPartsResponse.uploadId
        } else {
            alreadyUploadedParts = []
            let createRequest = AWSRequest.createMultipartUploadRequest(
                bucket: bucket,
                key: key,
                path: path,
                credentials: self.credentials
            )
            let createResponse = try S3CreateMultipartUploadResponse.from(response: await perform(createRequest))
            uploadId = createResponse.uploadId
        }

        let uploadedParts = try await file.uploadParts.parallelMap(parallelism: 8) { part in
            let existingPart = alreadyUploadedParts.first(where: { $0.number == part.0 })
            return try await self.uploadPart(
                withUploadId: uploadId,
                forRange: part.1,
                atIndex: part.0,
                existingPart: existingPart
            )
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

    func findMostRecentUncompletedParts() async throws -> S3ListPartsResponse? {
        let listPendingUploadRequest = AWSRequest.listMultipartUploadsRequest(
            bucket: bucket,
            key: key,
            credentials: self.credentials
        )
        let response = try S3ListMultipartUploadResponse.from(response: await perform(listPendingUploadRequest))
        if let latestUpload = response.mostRecentUpload {
            let listPartsRequest = AWSRequest.listPartsRequest(
                bucket: bucket,
                key: key,
                uploadId: latestUpload.uploadId,
                credentials: self.credentials
            )
            return try S3ListPartsResponse.from(response: await perform(listPartsRequest).validate())
        }
        return nil
    }

    func uploadPart(
        withUploadId uploadId: String,
        forRange range: Range<Int>,
        atIndex index: Int,
        existingPart: AWSUploadedPart?
    ) async throws -> AWSUploadedPart {

        let part = AWSPartData(
            uploadId: uploadId,
            number: index,
            data: try await file[range]
        )

        // Each part's ETag is the md5 of said part, wrapped in quotes.
        // Note that, as per HTTP spec, the quote literals are fully part of the ETag value
        // https://www.rfc-editor.org/rfc/rfc2616#section-3.11
        if let existingPart, existingPart.eTag == "\"\(md5Hash(data: part.data))\"" {
            // Skipping part as it has already been uploaded with matching ETag/md5
            self.progress.completedUnitCount += Int64(part.data.count)
            self.progress.estimateThroughput(fromStartDate: self.startDate)
            self.progressCallback?(self.progress)

            return existingPart
        }

        let request = AWSRequest.uploadPartRequest(
            bucket: bucket,
            key: key,
            part: part,
            credentials: self.credentials,
            endpoint: self.endpoint
        )

        let response = try await upload(request).validate()

        guard let eTag = response.value(forHTTPHeaderField: .eTag) else {
            throw CocoaError(.propertyListReadUnknownVersion)
        }

        return AWSUploadedPart(number: part.number, eTag: eTag)
    }

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
