import Foundation

struct AWSRequestSigner {

    let requestAuthenticationCode: Data

    init(
        credentials: AWSCredentials,
        requestDate: Date,
        requestType: String = "aws4_request",
        service: String = "s3"
    ) {
        let initialKey = Data("AWS4\(credentials.secretKey)".utf8)
        self.requestAuthenticationCode = [
            formattedDatestamp(from: requestDate),
            credentials.region,
            service,
            requestType
        ].reduce(into: initialKey) { $0 = HMAC256.sign(string: $1, key: $0) }
    }

    func sign(string: String) -> Data {
        HMAC256.sign(string: string, key: self.requestAuthenticationCode)
    }

    func sign(string: String) -> String {
        self.sign(string: string).hexEncodedString()
    }
}
