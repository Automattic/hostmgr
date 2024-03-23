import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AWSRequest {

    enum StorageClass: String {
        case reducedRedundancy = "REDUCED_REDUNDANCY"
    }

    let request: URLRequest
    let credentials: AWSCredentials
    let date: Date

    private let scope: AWSScope
    private let signer: AWSRequestSigner
    private let queryItems: [URLQueryItem]
    private let bucket: String
    private let path: String

    init(
        verb: HTTPMethod,
        bucket: String,
        path: String = "/",
        query: [URLQueryItem] = [],
        range: Range<Int>? = nil,
        storageClass: StorageClass? = nil,
        content: Data? = nil,
        contentSignature: String = sha256Hash(string: ""),
        credentials: AWSCredentials,
        date: Date = Date(),
        endpoint: S3Endpoint = .default,
        extraHeaders: [String: String] = [:]
    ) {
        var components = URLComponents()
        components.scheme = endpoint.scheme.rawValue
        components.host = endpoint.hostname(forBucket: bucket, inRegion: credentials.region)
        components.path = path.hasPrefix("/") ? path : "/" + path
        components.queryItems = query

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = verb.rawValue

        if let storageClass {
            urlRequest.setValue(storageClass.rawValue, forHTTPHeaderField: "x-amz-storage-class")
        }

        urlRequest.setValue(contentSignature, forHTTPHeaderField: "x-amz-content-sha256")
        urlRequest.setValue(formattedTimestamp(from: date), forHTTPHeaderField: "x-amz-date")

        for (key, value) in extraHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let range {
            let lowerBound = range.lowerBound
            let upperBound = range.upperBound

            urlRequest.setValue("bytes=\(lowerBound)-\(upperBound)", forHTTPHeaderField: "Range")
        }

        self.credentials = credentials
        self.date = date

        self.queryItems = query
        self.bucket = bucket
        self.path = path
        self.scope = AWSScope(region: credentials.region, date: date)
        self.signer = AWSRequestSigner(credentials: credentials, requestDate: date)

        urlRequest.httpBody = content
        self.request = urlRequest
    }

    public var headers: HttpHeaders {
        HttpHeaders().adding(request.allHTTPHeaderFields!)
    }
}

// MARK: Canonical Requeat
extension AWSRequest {
    var canonicalUri: String {
        request.url!.path
    }

    var escapedCanonicalUri: String {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove("$")

        return canonicalUri.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
    }

    var canonicalQueryString: String {
        queryItems
            .sorted()
            .asEscapedQueryString
    }

    var canonicalHeaders: HttpHeaders {
        HttpHeaders([
            .host: request.url!.host!
        ]).adding(request.allHTTPHeaderFields ?? [:])
    }

    var canonicalHeaderString: String {
        canonicalHeaders
            .toHttpHeaderFields
            .sorted { $0.key < $1.key }
            .map { $0.key.lowercased() + ":" + $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
    }

    var signedHeaderString: String {
        canonicalHeaders
            .toHttpHeaderFields
            .sorted { $0.key < $1.key }
            .map { $0.key.lowercased() }
            .joined(separator: ";")
    }

    var canonicalRequest: String {
        [
            request.httpMethod,
            escapedCanonicalUri,
            canonicalQueryString,
            canonicalHeaderString,
            "",
            signedHeaderString,
            request.allHTTPHeaderFields?["x-amz-content-sha256"]
        ].compactMap { $0 }.joined(separator: "\n")
    }
}

// MARK: String to Sign
extension AWSRequest {
    var stringToSign: String {
        [
            "AWS4-HMAC-SHA256",
            formattedTimestamp(from: self.date),
            self.scope.description,
            sha256Hash(string: canonicalRequest)
        ].joined(separator: "\n")
    }
}

// MARK: Signature
extension AWSRequest {
    var signature: String {
        signer.sign(string: stringToSign)
    }

    var authorizationHeaderValue: String {
        "AWS4-HMAC-SHA256 " + [
            "Credential=\(credentials.accessKeyId)/\(scope.description)",
            "SignedHeaders=\(signedHeaderString)",
            "Signature=\(signature)"
        ].joined(separator: ",")
    }

    var urlRequest: URLRequest {
        var request = self.request
        request.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        return request
    }
}

// MARK: Convenience Initializers
extension AWSRequest {
    static func listRequest(bucket: String, `prefix`: String = "", credentials: AWSCredentials) -> AWSRequest {
        AWSRequest(verb: .get, bucket: bucket, query: [
            URLQueryItem(name: "prefix", value: prefix)
        ], credentials: credentials)
    }

    static func headRequest(
        bucket: String,
        key: String,
        credentials: AWSCredentials
    ) -> AWSRequest {
        AWSRequest(
            verb: .head,
            bucket: bucket,
            path: key,
            credentials: credentials
        )
    }

    static func downloadRequest(
        bucket: String,
        key: String,
        range: Range<Int>? = nil,
        credentials: AWSCredentials,
        endpoint: S3Endpoint = .default,
        date: Date = Date()
    ) -> AWSRequest {
        AWSRequest(
            verb: .get,
            bucket: bucket,
            path: key,
            range: range,
            credentials: credentials,
            date: date,
            endpoint: endpoint
        )
    }

    static func listMultipartUploadsRequest(
        bucket: String,
        key: String,
        credentials: AWSCredentials,
        date: Date = Date()
    ) -> AWSRequest {
        AWSRequest(
            verb: .get,
            bucket: bucket,
            query: [
                URLQueryItem(name: "uploads", value: nil),
                URLQueryItem(name: "prefix", value: String(key.trimmingPrefix("/")))
            ],
            credentials: credentials,
            date: date
        )
    }

    static func listPartsRequest(
        bucket: String,
        key: String,
        uploadId: String,
        credentials: AWSCredentials,
        date: Date = Date()
    ) -> AWSRequest {
        AWSRequest(
            verb: .get,
            bucket: bucket,
            path: key,
            query: [URLQueryItem(name: "uploadId", value: uploadId)],
            credentials: credentials,
            date: date
        )
    }

    static func createMultipartUploadRequest(
        bucket: String,
        key: String,
        path: URL,
        credentials: AWSCredentials
    ) -> AWSRequest {
        AWSRequest(
            verb: .post,
            bucket: bucket,
            path: key,
            query: [URLQueryItem(name: "uploads", value: nil)],
            credentials: credentials
        )
    }

    static func uploadPartRequest(
        bucket: String,
        key: String,
        part: MultipartUploadOperation.AWSPartData,
        credentials: AWSCredentials,
        endpoint: S3Endpoint = .default
    ) throws -> AWSRequest {
        AWSRequest(
            verb: .put,
            bucket: bucket,
            path: key,
            query: [
                URLQueryItem(name: "partNumber", value: String(part.number)),
                URLQueryItem(name: "uploadId", value: part.uploadId)
            ],
            content: part.data,
            contentSignature: part.sha256Hash,
            credentials: credentials,
            endpoint: endpoint
        )
    }

    static func completeMultipartUploadRequest(
        bucket: String,
        key: String,
        uploadId: String,
        data: Data,
        credentials: AWSCredentials,
        date: Date = Date()
    ) -> AWSRequest {
        AWSRequest(
            verb: .post,
            bucket: bucket,
            path: key,
            query: [URLQueryItem(name: "uploadId", value: uploadId)],
            content: data,
            contentSignature: sha256Hash(data: data),
            credentials: credentials,
            date: date,
            extraHeaders: [
                "Content-Type": "application/xml"
            ]
        )
    }
}
