import XCTest
@testable import tinys3

final class S3ListResponseParserTests: XCTestCase {

    private var validList: S3ListResponse!
    private var emptyList: S3ListResponse!

    override func setUpWithError() throws {
        self.validList = try S3ListResponseParser(data: R.xmlData("ListBucketData")).parse()
        self.emptyList = try S3ListResponseParser(data: R.xmlData("ListBucketDataEmpty")).parse()
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
        let invalidBucketData = try R.xmlData("ListBucketDataInvalid")
        let invalidParser = S3ListResponseParser(data: invalidBucketData)
        XCTAssertThrowsError(try invalidParser.parse())
    }

    func testThatEmptyResponseThrows() throws {
        let invalidData = try R.xmlData("EmptyXML")
        let invalidParser = S3ListResponseParser(data: invalidData)
        XCTAssertThrowsError(try invalidParser.parse())
    }
}
