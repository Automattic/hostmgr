import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct S3HeadResponse {

    let key: String
    let response: AWSResponse

    public var s3Object: S3Object? {
        let modificationDateParser = DateFormatter()
        modificationDateParser.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"

        guard
            let contentLengthString = response.value(forHTTPHeaderField: .contentLength),
            let contentLength = Int(contentLengthString),
            let eTag = response.value(forHTTPHeaderField: .eTag),
            let lastModifiedString = response.value(forHTTPHeaderField: .lastModified),
            let lastModifiedAt = modificationDateParser.date(from: lastModifiedString)
        else {
            return nil
        }

        return S3Object(
            key: self.key,
            size: contentLength,
            eTag: eTag,
            lastModifiedAt: lastModifiedAt,
            storageClass: ""
        )
    }

    static func from(key: String, response: AWSResponse) -> S3HeadResponse {
        .init(key: key, response: response)
    }
}
