import XCTest
@testable import tinys3

final class S3CreateMultipartUploadResponseTests: XCTestCase {
    var response: S3CreateMultipartUploadResponse!

    override func setUpWithError() throws {
        let awsResponse = try AWSResponse.fixture("CreateMultipartUpload")
        self.response = try S3CreateMultipartUploadResponse.from(response: awsResponse)
    }

    func testThatBucketCanBeParsed() throws {
        XCTAssertEqual("a8c-macos-ci-images", response.bucket)
    }

    func testThatKeyCanBeParsed() throws {
        XCTAssertEqual("images/xcode-14.2.vmtemplate.aar", response.key)
    }

    func testThatUploadIdCanBeParsed() throws {
        // swiftlint:disable line_length
        XCTAssertEqual("vGhrpGPlS1rLpmLJ1itwiskYn5qXjgRTw.BlpzsHRh5d3d8FUjfG_0dvGG_HyWdVldVBhVtjJrAYSuEjiLDxVmwzfC3xIP18jTqx.6mpN07DWj.Mg3B31LXFdb2jIEMO", response.uploadId)
        // swiftlint:enable line_length
    }
}
