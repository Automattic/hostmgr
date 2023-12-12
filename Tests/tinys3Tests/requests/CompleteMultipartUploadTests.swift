import XCTest
@testable import tinys3

// swiftlint:disable line_length
final class CompleteMultipartUpload: XCTestCase, RequestTest {

    var request: AWSRequest = AWSRequest.completeMultipartUploadRequest(
        bucket: "examplebucket",
        key: "/test.txt",
        uploadId: "upload-id-example",
        data: Data(),
        credentials: .testDefault,
        date: .testDefault
    )

    func testThatCanonicalUriIsCorrect() throws {
        XCTAssertEqual("/test.txt", request.canonicalUri)
    }

    func testThatCanonicalQueryStringIsCorrect() throws {
        XCTAssertEqual("uploadId=upload-id-example", request.canonicalQueryString)
    }

    func testThatCanonicalHeaderStringIsCorrect() throws {
        XCTAssertEqual("""
content-type:application/xml
host:examplebucket.s3.amazonaws.com
x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
x-amz-date:20130524T000000Z
""", request.canonicalHeaderString)
    }

    func testThatSignedHeaderStringIsCorrect() throws {
        XCTAssertEqual("content-type;host;x-amz-content-sha256;x-amz-date", request.signedHeaderString)
    }

    func testThatCanonicalRequestIsValid() throws {
        XCTAssertEqual("""
POST
/test.txt
uploadId=upload-id-example
content-type:application/xml
host:examplebucket.s3.amazonaws.com
x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
x-amz-date:20130524T000000Z

content-type;host;x-amz-content-sha256;x-amz-date
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
""", request.canonicalRequest)
    }

    func testThatStringToSignIsValid() throws {
        XCTAssertEqual("""
AWS4-HMAC-SHA256
20130524T000000Z
20130524/us-east-1/s3/aws4_request
717360f4a6b1ccfb3726f7c27759c7ff8588db662677cb54b52a41abeaa18830
""", request.stringToSign)
    }

    func testThatSignatureIsValid() throws {
        XCTAssertEqual("f59f6ff646108d4259b2d17115dc240457f5c7c981f3f587fe5ff702a294d703", request.signature)
    }

    func testThatAuthorizationHeaderValueIsCorrect() throws {
        XCTAssertEqual("""
AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,Signature=f59f6ff646108d4259b2d17115dc240457f5c7c981f3f587fe5ff702a294d703
""", request.authorizationHeaderValue)
    }
}
