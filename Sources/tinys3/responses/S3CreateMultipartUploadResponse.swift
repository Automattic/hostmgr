import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

struct S3CreateMultipartUploadResponse {

    let bucket: String
    let key: String
    let uploadId: String

    static func from(response: AWSResponse) throws -> S3CreateMultipartUploadResponse {
        let doc = try XMLDocument(data: response.data)
        let root = try doc.rootElement(expectedName: "InitiateMultipartUploadResult")

        return S3CreateMultipartUploadResponse(
            bucket: try root.value(forElementName: "Bucket"),
            key: try root.value(forElementName: "Key"),
            uploadId: try root.value(forElementName: "UploadId")
        )
    }
}
