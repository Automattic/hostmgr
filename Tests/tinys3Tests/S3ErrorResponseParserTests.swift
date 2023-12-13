import XCTest
@testable import tinys3

final class S3ErrorResponseParserTests: XCTestCase {

    private var redirectError: S3ErrorResponse!

    override func setUpWithError() throws {
        self.redirectError = try S3ErrorResponseParser(data: R.xmlData("ErrorDataRedirect")).parse()
    }

    func testThatCodeCanBeParsed() throws {
        XCTAssertEqual("PermanentRedirect", redirectError.code)
    }

    func testThatMessageCanBeParsed() throws {
        XCTAssertEqual([
            "The bucket you are attempting to access must be addressed using the specified endpoint.",
            "Please send all future requests to this endpoint."
        ].joined(separator: " "), redirectError.message)
    }

    func testThatRequestIdCanBeParsed() throws {
        XCTAssertEqual("GVFEBNFDE20VQA1J", redirectError.requestId)
    }

    func testThatHostIdCanBeParsed() throws {
        XCTAssertEqual(
            "a0dYNTP713XzlbobHEBaEZjD6X4de5ISMPkjJlk6c9ImK0aaTCdjxVK953Ix/JH+zEsnB0g1BWI=",
            redirectError.hostId
        )
    }

    func testThatExtraContainsBucketName() {
        XCTAssertTrue(redirectError.extra.keys.contains("Bucket"))
        XCTAssertEqual(testBucketName, redirectError.extra["Bucket"])
    }

    func testThatExtraContainsEndpoint() {
        XCTAssertTrue(redirectError.extra.keys.contains("Endpoint"))
        XCTAssertEqual("my-test-bucket.s3.us-east-1.amazonaws.com", redirectError.extra["Endpoint"])
    }

    func testThatInvalidResponseThrows() throws {
        let invalidData = try R.xmlData("ListBucketData")
        let invalidParser = S3ErrorResponseParser(data: invalidData)
        XCTAssertThrowsError(try invalidParser.parse())
    }

    func testThatEmptyResponseThrows() throws {
        let emptyData = try R.xmlData("EmptyXML")
        let invalidParser = S3ErrorResponseParser(data: emptyData)
        XCTAssertThrowsError(try invalidParser.parse())
    }
}
