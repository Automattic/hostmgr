import XCTest
@testable import tinys3

// swiftlint:disable line_length
final class ListPartsRequestTests: XCTestCase, RequestTest {
    let request = AWSRequest.listPartsRequest(
        bucket: "examplebucket",
        key: "images/xcode-14.3.vmtemplate.aar",
        uploadId: testUploadId,
        credentials: .testDefault,
        date: .testDefault
    )

    func testThatCanonicalUriIsCorrect() throws {
        XCTAssertEqual("/images/xcode-14.3.vmtemplate.aar", request.canonicalUri)
    }

    func testThatCanonicalQueryStringIsCorrect() throws {
        XCTAssertEqual("uploadId=\(testUploadId)", request.canonicalQueryString)
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
            /images/xcode-14.3.vmtemplate.aar
            uploadId=\(testUploadId)
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
            1690ad2bfa2ff723e3d4ffa4ca0c82006b0c31a1125b19d20a30b8e997ee1112
            """, request.stringToSign)
    }

    func testThatSignatureIsValid() throws {
        XCTAssertEqual("4ed62783d291f214efd167d9f1e42b13e3eab36c8364d14a5ff7b1b315eebafd", request.signature)
    }

    func testThatAuthorizationHeaderValueIsCorrect() throws {
        XCTAssertEqual("""
            AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=host;x-amz-content-sha256;x-amz-date,Signature=4ed62783d291f214efd167d9f1e42b13e3eab36c8364d14a5ff7b1b315eebafd
            """, request.authorizationHeaderValue)
    }
}
// swiftlint:enable line_length
