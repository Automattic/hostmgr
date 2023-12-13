import XCTest
@testable import tinys3

// swiftlint:disable line_length
final class PresignedGetRequestTests: XCTestCase, RequestTest {

    let request = AWSRequest.downloadRequest(
        bucket: "examplebucket",
        key: "/test.txt",
        range: 0..<9,
        credentials: .testDefault,
        date: Date.testDefault
    )

    func testThatCanonicalUriIsCorrect() throws {
        XCTAssertEqual("/test.txt", request.canonicalUri)
    }

    func testThatCanonicalQueryStringIsCorrect() throws {
        XCTAssertEqual("", request.canonicalQueryString)
    }

    func testThatCanonicalHeaderStringIsCorrect() throws {
        XCTAssertEqual("""
    host:examplebucket.s3.amazonaws.com
    range:bytes=0-9
    x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    x-amz-date:20130524T000000Z
    """, request.canonicalHeaderString)
    }

    func testThatSignedHeaderStringIsCorrect() throws {
        XCTAssertEqual("host;range;x-amz-content-sha256;x-amz-date", request.signedHeaderString)
    }

    func testThatCanonicalRequestIsValid() throws {
        XCTAssertEqual("""
    GET
    /test.txt

    host:examplebucket.s3.amazonaws.com
    range:bytes=0-9
    x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    x-amz-date:20130524T000000Z

    host;range;x-amz-content-sha256;x-amz-date
    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    """, request.canonicalRequest)
    }

    func testThatStringToSignIsValid() throws {
        XCTAssertEqual("""
    AWS4-HMAC-SHA256
    20130524T000000Z
    20130524/us-east-1/s3/aws4_request
    7344ae5b7ee6c3e7e6b0fe0640412a37625d1fbfff95c48bbb2dc43964946972
    """, request.stringToSign)
    }

    func testThatSignatureIsValid() throws {
        XCTAssertEqual("f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41", request.signature)
    }

    func testThatAuthorizationHeaderValueIsCorrect() throws {
        XCTAssertEqual("""
    AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=host;range;x-amz-content-sha256;x-amz-date,Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41
    """, request.authorizationHeaderValue)
    }
}
// swiftlint:enable line_length
