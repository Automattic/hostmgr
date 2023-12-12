import XCTest
@testable import tinys3

// swiftlint:disable line_length
final class PresignedPutRequestTests: XCTestCase, RequestTest {
    var request = AWSRequest(
        verb: .put,
        bucket: "examplebucket",
        path: "/test$file.text",
        storageClass: .reducedRedundancy,
        contentSignature: sha256Hash(string: "Welcome to Amazon S3."),
        credentials: .testDefault,
        date: .testDefault,
        extraHeaders: [
            "Date": "Fri, 24 May 2013 00:00:00 GMT"
        ]
    )

    func testThatCanonicalUriIsCorrect() throws {
        XCTAssertEqual("/test$file.text", request.canonicalUri)
    }

    func testThatCanonicalQueryStringIsCorrect() throws {
        XCTAssertEqual("", request.canonicalQueryString)
    }

    func testThatCanonicalHeaderStringIsCorrect() throws {
        XCTAssertEqual("""
date:Fri, 24 May 2013 00:00:00 GMT
host:examplebucket.s3.amazonaws.com
x-amz-content-sha256:44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072
x-amz-date:20130524T000000Z
x-amz-storage-class:REDUCED_REDUNDANCY
""", request.canonicalHeaderString)
    }

    func testThatSignedHeaderStringIsCorrect() throws {
        XCTAssertEqual("date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class", request.signedHeaderString)
    }

    func testThatCanonicalRequestIsValid() throws {
        XCTAssertEqual("""
PUT
/test%24file.text

date:Fri, 24 May 2013 00:00:00 GMT
host:examplebucket.s3.amazonaws.com
x-amz-content-sha256:44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072
x-amz-date:20130524T000000Z
x-amz-storage-class:REDUCED_REDUNDANCY

date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class
44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072
""", request.canonicalRequest)
    }

    func testThatStringToSignIsValid() throws {
        XCTAssertEqual("""
AWS4-HMAC-SHA256
20130524T000000Z
20130524/us-east-1/s3/aws4_request
9e0e90d9c76de8fa5b200d8c849cd5b8dc7a3be3951ddb7f6a76b4158342019d
""", request.stringToSign)
    }

    func testThatSignatureIsValid() throws {
        XCTAssertEqual("98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd", request.signature)
    }

    func testThatAuthorizationHeaderValueIsCorrect() throws {
        XCTAssertEqual("""
AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class,Signature=98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd
""", request.authorizationHeaderValue)
    }
}
