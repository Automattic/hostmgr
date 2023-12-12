import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AWSPresignedDownloadURL {
    let bucket: String
    let key: String
    let ttl: TimeInterval
    let endpoint: S3Endpoint

    private let verb: HTTPMethod

    private let credentials: AWSCredentials
    private let date: Date

    private let scope: AWSScope
    private let signer: AWSRequestSigner

    init(
        verb: HTTPMethod = .get,
        bucket: String,
        key: String,
        ttl: TimeInterval = 30,
        endpoint: S3Endpoint = .default,
        credentials: AWSCredentials,
        date: Date = Date()
    ) {
        self.verb = verb
        self.bucket = bucket
        self.key = key
        self.ttl = ttl
        self.endpoint = endpoint
        self.credentials = credentials
        self.date = date

        self.scope = AWSScope(region: credentials.region, date: date)
        self.signer = AWSRequestSigner(credentials: credentials, requestDate: date)
    }

    var hostname: String {
        endpoint.hostname(forBucket: bucket, inRegion: credentials.region)
    }

    var canonicalUri: String {
        self.key.hasPrefix("/") ? self.key : "/" + self.key
    }

    var queryItems: [URLQueryItem] {
        [
            "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
            "X-Amz-Credential": credentials.accessKeyId + "/" + scope.description,
            "X-Amz-Date": formattedTimestamp(from: date),
            "X-Amz-Expires": "\(Int(ttl))",
            "X-Amz-SignedHeaders": signedHeaderString
        ] .map { URLQueryItem(name: $0.key, value: $0.value ) }
    }

    var canonicalQueryString: String {
        queryItems.sorted().asEscapedQueryString
    }

    var canonicalHeaderString: String {
        "host:" + hostname
    }

    var signedHeaderString: String {
        "host"
    }

    var canonicalRequest: String {
        [
            self.verb.rawValue,
            canonicalUri,
            canonicalQueryString,
            canonicalHeaderString,
            "",
            signedHeaderString,
            "UNSIGNED-PAYLOAD"
        ].joined(separator: "\n")
    }

    var stringToSign: String {
        [
            "AWS4-HMAC-SHA256",
            formattedTimestamp(from: date),
            scope.description,
            sha256Hash(string: canonicalRequest)
        ].joined(separator: "\n")
    }

    var signature: String {
        signer.sign(string: stringToSign)
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = hostname
        components.path = canonicalUri.hasPrefix("/") ? canonicalUri : "/" + canonicalUri
        components.percentEncodedQuery = (queryItems.sorted() + [
            URLQueryItem(name: "X-Amz-Signature", value: signature)
        ]).asEscapedQueryString

        return components.url!
    }
}
