import XCTest
@testable import tinys3

final class S3ListMultipartUploadResponseTests: XCTestCase {
    var response: S3ListMultipartUploadResponse!

    override func setUpWithError() throws {
        let awsResponse = try AWSResponse.fixture("ListMultipartUploadsResult")
        self.response = try S3ListMultipartUploadResponse.from(response: awsResponse)
    }

    func testThatBucketCanBeParsed() throws {
        XCTAssertEqual(testBucketName, response.bucket)
    }

    func testThatPartsCanBeParsed() throws {
        XCTAssertEqual(2, response.uploads.count)
        XCTAssertEqual(response.uploads[0].key, "images/xcode-15.3-v3.vmtemplate.aar")
        XCTAssertEqual(response.uploads[0].uploadId, "X2j2QvTjRhdwf6xT0p7bdR3ew91")
        XCTAssertEqual(response.uploads[0].initiatedDate, Date(timeIntervalSince1970: 1711033874))
        XCTAssertEqual(response.uploads[1].key, "images/xcode-15.3-v3.vmtemplate.aar")
        XCTAssertEqual(response.uploads[1].uploadId, testUploadId)
        XCTAssertEqual(response.uploads[1].initiatedDate, Date(timeIntervalSince1970: 1711041507))
    }
}
