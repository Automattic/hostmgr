import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

public struct S3ListResponse {

    public let bucketName: String
    public let prefix: String?
    public let marker: String?
    public let maxKeys: Int
    public let isTruncated: Bool
    public let objects: [S3Object]

    static func from(response: AWSResponse) throws -> S3ListResponse {
        let doc = try XMLDocument(data: response.data)
        let root = try doc.rootElement(expectedName: "ListBucketResult")

        let bucketName = try root.value(forElementName: "Name")
        let prefix = try? root.value(forElementName: "Prefix")
        let marker = try? root.value(forElementName: "Marker")
        let maxKeys = try root.value(forElementName: "MaxKeys", transform: Int.init)
        let isTruncated = try root.value(forElementName: "IsTruncated", transform: Bool.init)

        let objects = try root.elements(forName: "Contents").map { node in
            S3Object(
                key: try node.value(forElementName: "Key"),
                size: try node.value(forElementName: "Size", transform: Int.init),
                eTag: try node.value(forElementName: "ETag"),
                lastModifiedAt: try node.value(forElementName: "LastModified", transform: parseISO8601String),
                storageClass: try node.value(forElementName: "StorageClass")
            )
        }

        return S3ListResponse(
            bucketName: bucketName,
            prefix: prefix?.nilIfEmpty,
            marker: marker?.nilIfEmpty,
            maxKeys: maxKeys,
            isTruncated: isTruncated,
            objects: objects
        )
    }
}
