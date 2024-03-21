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
        guard let root = doc.rootElement(), root.name == "InitiateMultipartUploadResult" else {
            throw InvalidDataError()
        }

        guard
            let bucket = root.elements(forName: "Bucket").first?.stringValue,
            let key = root.elements(forName: "Key").first?.stringValue,
            let uploadId = root.elements(forName: "UploadId").first?.stringValue
        else {
            throw InvalidDataError()
        }

        return S3CreateMultipartUploadResponse(
            bucket: bucket,
            key: key,
            uploadId: uploadId
        )
    }
}
