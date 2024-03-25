import XCTest
@testable import tinys3

// swiftlint:disable line_length
final class ListMultipartUploadsRequestTests: XCTestCase, RequestTest {
    let request = AWSRequest.listMultipartUploadsRequest(
        bucket: "examplebucket",
        key: "images/xcode-14.3.vmtemplate.aar",
        credentials: .testDefault,
        date: .testDefault
    )

    func testThatCanonicalUriIsCorrect() throws {
        XCTAssertEqual("/", request.canonicalUri)
    }

    func testThatCanonicalQueryStringIsCorrect() throws {
        XCTAssertEqual("prefix=images%2Fxcode-14.3.vmtemplate.aar&uploads=", request.canonicalQueryString)
    }

    func testThatCanonicalHeaderStringIsCorrect() throws {
        XCTAssertEqual("""
            host:examplebucket.s3.amazonaws.com
            x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
            x-amz-date:20130524T000000Z
            """, request.canonicalHeaderString)
    }

    func testThatSignedHeaderStringIsCorrect() throws {
        XCTAssertEqual("host;x-amz-content-sha256;x-amz-date", request.signedHeaderString)
    }

    func testThatCanonicalRequestIsValid() throws {
        XCTAssertEqual("""
            GET
            /
            prefix=images%2Fxcode-14.3.vmtemplate.aar&uploads=
            host:examplebucket.s3.amazonaws.com
            x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
            x-amz-date:20130524T000000Z

            host;x-amz-content-sha256;x-amz-date
            e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
            """, request.canonicalRequest)
    }

    func testThatStringToSignIsValid() throws {
        XCTAssertEqual("""
            AWS4-HMAC-SHA256
            20130524T000000Z
            20130524/us-east-1/s3/aws4_request
            90f9822ca97b1ca0de0d1b0b4afb8137cf97ad4d07396aa6686a1cfacb6dc124
            """, request.stringToSign)
    }

    func testThatSignatureIsValid() throws {
        XCTAssertEqual("5feb3c99fc520055ad41dcb6c99dfb714d6bfdf670eb44a4dd14b289b9a5b4ed", request.signature)
    }

    func testThatAuthorizationHeaderValueIsCorrect() throws {
        XCTAssertEqual("""
            AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=host;x-amz-content-sha256;x-amz-date,Signature=5feb3c99fc520055ad41dcb6c99dfb714d6bfdf670eb44a4dd14b289b9a5b4ed
            """, request.authorizationHeaderValue)
    }
}
// swiftlint:enable line_length
