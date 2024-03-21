import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

struct S3ListPartsResponse {

    struct S3MultipartUpload {
        let key: String
        let uploadId: String
        let initiatedDate: Date
    }

    let bucket: String
    let key: String
    let uploadId: String
    let parts: [MultipartUploadOperation.AWSUploadedPart]

    static func from(response: AWSResponse) throws -> S3ListPartsResponse {
        let doc = try XMLDocument(data: response.data)
        let root = try doc.rootElement(expectedName: "ListPartsResult")

        let parts = try root.elements(forName: "Part").map {
            let partNumber = try $0.value(forElementName: "PartNumber", transform: Int.init)
            let eTag = try $0.value(forElementName: "ETag")
            return MultipartUploadOperation.AWSUploadedPart(number: partNumber, eTag: eTag)
        }

        return S3ListPartsResponse(
            bucket: try root.value(forElementName: "Bucket"),
            key: try root.value(forElementName: "Key"),
            uploadId: try root.value(forElementName: "UploadId"),
            parts: parts
        )
    }
}
