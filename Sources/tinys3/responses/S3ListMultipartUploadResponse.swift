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
        let root = try doc.rootElement(expectedName: "ListMultipartUploadsResult")

        let uploads = try root.elements(forName: "Upload").map {
            S3MultipartUpload(
                key: try $0.value(forElementName: "Key"),
                uploadId: try $0.value(forElementName: "UploadId"),
                initiatedDate: try $0.value(forElementName: "Initiated", transform: parseISO8601String)
            )
        }

        return S3ListMultipartUploadResponse(
            bucket: try root.value(forElementName: "Bucket"),
            uploads: uploads
        )
    }

    var mostRecentUpload: S3MultipartUpload? {
        self.uploads.max { $0.initiatedDate < $1.initiatedDate }
    }
}
