import Foundation

enum URLScheme: String {
    case http
    case https
}

public struct S3Endpoint: Equatable {
    let domain: String
    let usesHttps: Bool
    let port: Int?
    let usesBucketSubdomains: Bool
    let isAWS: Bool
    let needsRegion: Bool

    public static let `default` = S3Endpoint(
        domain: "s3.amazonaws.com",
        usesHttps: true,
        port: nil,
        usesBucketSubdomains: true,
        isAWS: true,
        needsRegion: false
    )
    public static let accelerated = S3Endpoint(
        domain: "s3-accelerate.amazonaws.com",
        usesHttps: true,
        port: nil,
        usesBucketSubdomains: true,
        isAWS: true,
        needsRegion: false
    )

    public static func custom(
        domain: String,
        port: Int? = nil,
        usesHttps: Bool = true,
        usesBucketSubdomains: Bool = true,
        needsRegion: Bool = false
    ) -> S3Endpoint {
        S3Endpoint(
            domain: domain,
            usesHttps: usesHttps,
            port: port,
            usesBucketSubdomains: usesBucketSubdomains,
            isAWS: false,
            needsRegion: needsRegion
        )
    }

    var scheme: URLScheme {
        usesHttps ? .https : .http
    }

    func hostname(forBucket bucketName: String, inRegion region: String) -> String {
        guard self.usesBucketSubdomains else {
            return self.domain
        }

        guard self.needsRegion else {
            return [
                bucketName,
                self.domain
            ].joined(separator: ".")
        }

        return [
            bucketName,
            "s3",
            region,
            self.domain
        ].joined(separator: ".")
    }

    func path(forKey key: String, inBucket bucket: String) -> String {
        guard !self.usesBucketSubdomains else {
            return key
        }

        if key.starts(with: "/") {
            return [bucket, key].joined()
        } else {
            return [bucket, key].joined(separator: "/")
        }
    }
}
