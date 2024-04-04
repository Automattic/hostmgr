import XCTest
import Foundation
import Crypto
@testable import tinys3

let testBucketName = "my-test-bucket"
let testObjectKey = "/my/path/to/stuff.txt"
let testPrefix = "my/path/"
// swiftlint:disable:next line_length
let testUploadId = "q4sTIuOL6NEI9mEHjfORyTfaMSvkA3ebJhiwuTi4xfPhqtM8yasXIjBM8tuGhq9TpdfrNi7uhdHBWWeadoRo3iJ770lPeC8Px1w0stBEXMAZN2jZYrJDqSAWR3DkUJj9"

extension AWSCredentials {
    /// Valid, but deleted credentials – created only for use with this project, then destroyed immediately.
    static let testDefault = AWSCredentials(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1"
    )
}

extension AWSRequest {
    // Use this to generate the expected values for Tests conforming to RequestTest protocol
    func printDebugSigningRubyCode() {
        let headers = (self.request.allHTTPHeaderFields ?? [:]).map { "'\($0.key)' => '\($0.value)'" }
        let urlString: String = {
            // self.absoluteString does not escape `/` in its query items, but `Aws::Sigv4::Signer` requires those to be
            guard
                let comps = self.request.url.flatMap({ URLComponents(string: $0.absoluteString) }),
                let fixedUrl = comps.string
            else {
                return self.request.url?.absoluteString ?? ""
            }
            guard let range = comps.rangeOfQuery else { return fixedUrl }
            return fixedUrl.replacingOccurrences(of: "/", with: "%2F", range: range)
        }()
        let body = self.request.httpBody.flatMap { String(data: $0, encoding: .utf8) }

        let code = """
        # Paste and run the following code to a Ruby interpreter (e.g. `irb`)
        # to check the expected values for `RequestTest` test methods

        require 'aws-sigv4'
        signer = Aws::Sigv4::Signer.new(
            service: 's3',
            region: '\(self.credentials.region)',
            access_key_id: '\(self.credentials.accessKeyId)',
            secret_access_key: '\(self.credentials.secretKey)'
        )
        signature = signer.sign_request(
            http_method: '\(self.request.httpMethod ?? "GET")',
            url: '\(urlString)',
            headers: {
                \(headers.joined(separator: ",\n        "))
            },
            body: \(body.map { "<<-BODY\n\($0)\nBODY" } ?? "nil")
        )

        puts "-- testThatCanonicalHeaderStringIsCorrect",
            signature.headers.reject { _1 == 'authorization' }.sort.map { "#{_1}:#{_2}" }.join("\\n")
        puts "-- testThatCanonicalRequestIsValid",
            signature.canonical_request
        puts "-- testThatStringToSignIsValid",
            signature.string_to_sign
        puts "-- testThatAuthorizationHeaderValueIsCorrect",
            signature.headers['authorization'].gsub(', ', ',')
        """
        print(code)
    }
}

extension Date {
    static var testDefault: Date {
        Date(timeIntervalSince1970: 1369353600)
    }
}

// swiftlint:disable type_name
struct R {
// swiftlint:enable type_name
    static func string(_ name: String) throws -> String {
        return try String(contentsOf: url(forResourceName: name, withExtension: "txt"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func xmlString(_ name: String) throws -> String {
        return try String(contentsOf: url(forResourceName: name, withExtension: "xml"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func xmlData(_ name: String) throws -> Data {
        return try Data(contentsOf: url(forResourceName: name, withExtension: "xml"))
    }

    private static func url(forResourceName name: String, withExtension ext: String) throws -> URL {
        let desc = "There's no file named \(name).\(ext) in the module – you might need to register it in Package.swift"

        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            throw ResourceNotFoundError(errorDescription: desc)
        }

        return url
    }

    struct ResourceNotFoundError: LocalizedError {
        let errorDescription: String
    }

    enum AWSCredentialsFixture: String {
        case multiple = "aws-credentials-file-multiple"
        case withoutRegion = "aws-credentials-file-no-region"
        case single = "aws-credentials-file-single"

        var string: String { get throws { try R.string(self.rawValue) } }
        var profiles: [AWSProfile: AWSProfileConfig] {
            get throws {
                try AWSProfileConfigFileParser.profiles(from: self.string, fileType: .credentials)
            }
        }
    }

    enum AWSUserConfigFixture: String {
        case multiple = "aws-config-file-multiple"
        case withoutRegion = "aws-config-file-no-region"
        case single = "aws-config-file-single"

        var string: String { get throws { try R.string(self.rawValue) } }
        var profiles: [AWSProfile: AWSProfileConfig] {
            get throws {
                try AWSProfileConfigFileParser.profiles(from: self.string, fileType: .config)
            }
        }
    }
}

extension AWSResponse {
    static func fixture(_ name: String) throws -> AWSResponse {
        try AWSResponse(response: HTTPURLResponse(), data: R.xmlData(name))
    }
}
