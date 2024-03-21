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

    struct AWSCredentialsFile {
        static var multiple: String { get throws { try R.string("aws-credentials-file-multiple") } }
        static var withoutRegion: String { get throws { try R.string("aws-credentials-file-no-region")}}
        static var single: String { get throws { try R.string("aws-credentials-file-single") } }
    }
}

extension AWSResponse {
    static func fixture(_ name: String) throws -> AWSResponse {
        try AWSResponse(response: HTTPURLResponse(), data: R.xmlData(name))
    }
}
