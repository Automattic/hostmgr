import XCTest
@testable import tinys3

final class AWSRequestTests: XCTestCase {

    let defaultRequest = AWSRequest(
        verb: .head,
        bucket: testBucketName,
        path: testObjectKey,
        credentials: .testDefault,
        date: .testDefault
    )

    func testThatDateHeaderIsSetByInit() {
        XCTAssertEqual("20130524T000000Z", defaultRequest.headers[.xAmzDate])
    }

    func testThatContentHashHeaderIsSetByInit() {
        XCTAssertEqual(sha256Hash(data: Data()), defaultRequest.headers[.xAmxContentSha256])
    }

    // MARK: URLRequest Validation
    func testThatUrlRequestConversionUsesCorrectScheme() throws {
        XCTAssertEqual(
            "https",
            try XCTUnwrap(defaultRequest.urlRequest.url).scheme
        )
    }

    func testThatUrlRequestConversionUsesCorrectHost() throws {
        XCTAssertEqual(
            "my-test-bucket.s3.amazonaws.com",
            try XCTUnwrap(defaultRequest.urlRequest.url).host
        )
    }

    func testThatUrlRequestConversionHasSha256Header() throws {
        XCTAssertEqual(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            try XCTUnwrap(defaultRequest.urlRequest.value(forHTTPHeaderField: "x-amz-content-sha256"))
        )
    }

    func testThatUrlRequestConversionHasAMZDateHeader() throws {
        XCTAssertEqual(
            "20130524T000000Z",
            try XCTUnwrap(defaultRequest.urlRequest.value(forHTTPHeaderField: "x-amz-date"))
        )
    }

    func testThatUrlRequestConversionHasAuthorizationHeader() throws {
//        XCTAssertEqual(
//            defaultRequest.authorizationHeaderValue,
//            try XCTUnwrap(defaultRequest.urlRequest.value(forHTTPHeaderField: "Authorization"))
//        )
    }
}
