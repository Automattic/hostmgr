import XCTest
@testable import tinys3

final class S3ListPartsResponseTests: XCTestCase {
    var response: S3ListPartsResponse!

    override func setUpWithError() throws {
        let awsResponse = try AWSResponse.fixture("ListPartsResponseResult")
        self.response = try S3ListPartsResponse.from(response: awsResponse)
    }

    func testThatBucketCanBeParsed() throws {
        XCTAssertEqual(testBucketName, response.bucket)
    }

    func testThatKeyCanBeParsed() throws {
        XCTAssertEqual(testObjectKey, response.key)
    }

    func testThatUploadIdCanBeParsed() throws {
        XCTAssertEqual(testUploadId, response.uploadId)
    }

    func testThatPartsCanBeParsed() throws {
        XCTAssertEqual(4, response.parts.count)
        XCTAssertEqual(response.parts[0].number, 1)
        XCTAssertEqual(response.parts[0].eTag, "\"5b6ccd4a982b8cc205b676a1c71878c2\"")
        XCTAssertEqual(response.parts[1].number, 2)
        XCTAssertEqual(response.parts[1].eTag, "\"b90567c3ce1a7db9a238eb4eba39b2fc\"")
        XCTAssertEqual(response.parts[2].number, 3)
        XCTAssertEqual(response.parts[2].eTag, "\"cc5558fd7f4b7bddf27c8520da9b1143\"")
        XCTAssertEqual(response.parts[3].number, 4)
        XCTAssertEqual(response.parts[3].eTag, "\"b58e72fa0407d19d562dc195c0eba648\"")
    }
}
