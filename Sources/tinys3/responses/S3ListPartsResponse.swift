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
        guard let root = doc.rootElement(), root.name == "ListPartsResult" else {
            throw InvalidDataError()
        }

        guard
            let bucketName = root.elements(forName: "Bucket").first?.stringValue,
            let objectKey = root.elements(forName: "Key").first?.stringValue,
            let uploadId = root.elements(forName: "UploadId").first?.stringValue
        else {
            throw InvalidDataError()
        }

        let parts = try root.elements(forName: "Part").map {
            guard
                let partNumber = $0.elements(forName: "PartNumber").first?.stringValue.flatMap({ Int($0) }),
                let eTag = $0.elements(forName: "ETag").first?.stringValue
            else {
                throw InvalidDataError()
            }
            return MultipartUploadOperation.AWSUploadedPart(number: partNumber, eTag: eTag)
        }

        return S3ListPartsResponse(
            bucket: bucketName,
            key: objectKey,
            uploadId: uploadId,
            parts: parts
        )
    }
}
