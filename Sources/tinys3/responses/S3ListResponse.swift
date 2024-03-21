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
        guard let root = doc.rootElement(), root.name == "ListBucketResult" else {
            throw InvalidDataError()
        }

        guard
            let bucketName = root.elements(forName: "Name").first?.stringValue,
            let maxKeys = root.elements(forName: "MaxKeys").first?.stringValue.flatMap({ Int($0) }),
            let isTruncated = root.elements(forName: "IsTruncated").first?.stringValue.flatMap({ Bool($0) })
        else {
            throw InvalidDataError()
        }

        let prefix = root.elements(forName: "Prefix").first?.stringValue
        let marker = root.elements(forName: "Marker").first?.stringValue

        let objects = try root.elements(forName: "Contents").map { node in
            guard
                let key = node.elements(forName: "Key").first?.stringValue,
                let size = node.elements(forName: "Size").first?.stringValue.flatMap({ Int($0) }),
                let eTag = node.elements(forName: "ETag").first?.stringValue,
                let lastModified = node.elements(forName: "LastModified").first?.stringValue.flatMap(parseISO8601String),
                let storageClass = node.elements(forName: "StorageClass").first?.stringValue
            else {
                throw InvalidDataError()
            }

            return S3Object(
                key: key,
                size: size,
                eTag: eTag,
                lastModifiedAt: lastModified,
                storageClass: storageClass
            )
        }

        return S3ListResponse(
            bucketName: bucketName,
            prefix: prefix?.isEmpty == true ? nil : prefix,
            marker: marker?.isEmpty == true ? nil : marker,
            maxKeys: maxKeys,
            isTruncated: isTruncated,
            objects: objects
        )
    }
}
