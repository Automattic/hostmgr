import XCTest
@testable import tinys3

final class S3ListResponseTests: XCTestCase {

    private var validList: S3ListResponse!
    private var emptyList: S3ListResponse!

    override func setUpWithError() throws {
        self.validList = try S3ListResponse.from(response: .fixture("ListBucketData"))
        self.emptyList = try S3ListResponse.from(response: .fixture("ListBucketDataEmpty"))
    }

    func testThatBucketNameCanBeParsed() throws {
        XCTAssertEqual("my-test-bucket", validList.bucketName)
        XCTAssertEqual("my-empty-bucket", emptyList.bucketName)
    }

    func testThatPrefixCanBeParsed() throws {
        XCTAssertEqual(testPrefix, validList.prefix)
        XCTAssertNil(emptyList.prefix)
    }

    func testThatMarkerCanBeParsed() throws {
        XCTAssertNil(validList.marker)
        XCTAssertNil(emptyList.marker)
    }

    func testThatMaxKeysCanBeParsed() throws {
        XCTAssertEqual(1000, validList.maxKeys)
        XCTAssertEqual(1000, emptyList.maxKeys)
    }

    func testThatIsTruncatedCanBeParsed() throws {
        XCTAssertEqual(false, validList.isTruncated)
        XCTAssertEqual(false, emptyList.isTruncated)
    }

    func testThatS3ObjectCountIsValid() throws {
        XCTAssertEqual(13, validList.objects.count)
        XCTAssertEqual(0, emptyList.objects.count)
    }

    func testThatInvalidResponseThrows() throws {
        let invalidBucketData = try AWSResponse.fixture("ListBucketDataInvalid")
        XCTAssertThrowsError(try S3ListResponse.from(response: invalidBucketData))
    }

    func testThatEmptyResponseThrows() throws {
        let invalidData = try AWSResponse.fixture("EmptyXML")
        XCTAssertThrowsError(try S3ListResponse.from(response: invalidData))
    }
}
