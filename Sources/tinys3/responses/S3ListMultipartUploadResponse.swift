import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

struct S3ListMultipartUploadResponse {

    struct S3MultipartUpload {
        let key: String
        let uploadId: String
        let initiatedDate: Date
    }

    let bucket: String
    let uploads: [S3MultipartUpload]

    static func from(response: AWSResponse) throws -> S3ListMultipartUploadResponse {
        let doc = try XMLDocument(data: response.data)
        guard let root = doc.rootElement(), root.name == "ListMultipartUploadsResult" else {
            throw InvalidDataError()
        }

        guard let bucketNode = root.elements(forName: "Bucket").first, let bucketName = bucketNode.stringValue else {
            throw InvalidDataError()
        }

        let uploads = try root.elements(forName: "Upload").map {
            guard
                let key = $0.elements(forName: "Key").first?.stringValue,
                let uploadId = $0.elements(forName: "UploadId").first?.stringValue,
                let initiatedString = $0.elements(forName: "Initiated").first?.stringValue,
                let initiatedDate = parseISO8601String(initiatedString)
            else {
                throw InvalidDataError()
            }
            return S3MultipartUpload(key: key, uploadId: uploadId, initiatedDate: initiatedDate)
        }

        return S3ListMultipartUploadResponse(bucket: bucketName, uploads: uploads)
    }

    var mostRecentUpload: S3MultipartUpload? {
        self.uploads.max { $0.initiatedDate < $1.initiatedDate }
    }
}
