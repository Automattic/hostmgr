import XCTest
@testable import tinys3

// swiftlint:disable line_length
final class PresignedURLGetRequestTests: XCTestCase {

    let request = AWSPresignedDownloadURL(
        bucket: "examplebucket",
        key: "/test.txt",
        ttl: 86400,
        credentials: .testDefault,
        date: .testDefault
    )

    func testThatHostnameIsCorrect() throws {
        XCTAssertEqual("examplebucket.s3.amazonaws.com", request.hostname)
    }

    func testThatCanonicalUriIsCorrect() throws {
        XCTAssertEqual("/test.txt", request.canonicalUri)
    }

    func ensureThatCanonicalUriIsValidIfMissingLeadingSlash() throws {
        let request = AWSPresignedDownloadURL(bucket: "examplebucket", key: "test.txt", credentials: .testDefault)
        XCTAssertEqual("/test.txt", request.canonicalUri)
    }

    func testThatCanonicalQueryStringIsCorrect() throws {
        XCTAssertEqual("""
X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
""", request.canonicalQueryString)
    }

    func testThatCanonicalHeaderStringIsCorrect() throws {
        XCTAssertEqual("host:examplebucket.s3.amazonaws.com", request.canonicalHeaderString)
    }

    func testThatSignedHeaderStringIsCorrect() throws {
        XCTAssertEqual("host", request.signedHeaderString)
    }

    func testThatCanonicalRequestIsValid() throws {
        XCTAssertEqual("""
GET
/test.txt
X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
host:examplebucket.s3.amazonaws.com

host
UNSIGNED-PAYLOAD
""", request.canonicalRequest)
    }

    func testThatStringToSignIsValid() throws {
        XCTAssertEqual("""
AWS4-HMAC-SHA256
20130524T000000Z
20130524/us-east-1/s3/aws4_request
3bfa292879f6447bbcda7001decf97f4a54dc650c8942174ae0a9121cf58ad04
""", request.stringToSign)
    }

    func testThatSignatureIsValid() throws {
        XCTAssertEqual("aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404", request.signature)
    }

    func testThatPresignedURLIsCorrect() throws {
        let correctURL = """
https://examplebucket.s3.amazonaws.com/test.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404
"""
        XCTAssertEqual(correctURL, request.url.absoluteString)
    }
}
