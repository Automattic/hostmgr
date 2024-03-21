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

        guard let bucketName = root.elements(forName: "Bucket").first?.stringValue else {
            throw InvalidDataError()
        }
        guard let objectKey = root.elements(forName: "Key").first?.stringValue else {
            throw InvalidDataError()
        }
        guard let uploadId = root.elements(forName: "UploadId").first?.stringValue else {
            throw InvalidDataError()
        }

        let parts = try root.elements(forName: "Part").map {
            guard
                let partString = $0.elements(forName: "PartNumber").first?.stringValue,
                let partNum = Int(partString),
                let eTag = $0.elements(forName: "ETag").first?.stringValue
            else {
                throw InvalidDataError()
            }
            return MultipartUploadOperation.AWSUploadedPart(number: partNum, eTag: eTag)
        }

        return S3ListPartsResponse(
            bucket: bucketName,
            key: objectKey,
            uploadId: uploadId,
            parts: parts
        )
    }
}
