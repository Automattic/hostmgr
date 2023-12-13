import XCTest
@testable import tinys3

final class AWSCredentialsFileParserTests: XCTestCase {

    func testThatSingleFileContainsDefaultCredentials() throws {
        XCTAssertNotNil(try AWSCredentialsFileParser(string: R.AWSCredentialsFile.single).parse()["default"])
    }

    func testThatParserReturnsNilForInvalidProfile() throws {
        XCTAssertNil(try AWSCredentialsFileParser(string: R.AWSCredentialsFile.single).parse()["invalid"])
    }

    func testThatSingleFileContainsValidCredentials() throws {
        XCTAssertEqual(
            try AWSCredentialsFileParser(string: R.AWSCredentialsFile.single).parse()["default"],
            AWSCredentials.testDefault
        )
    }

    func testThatFileWithoutRegionThrows() {
        XCTAssertThrowsError(
            try AWSCredentialsFileParser(string: R.AWSCredentialsFile.withoutRegion).parse()["default"]
        )
    }

    func testThatMultipleFileDiscardsInvalidSections() throws {
        let file = try R.AWSCredentialsFile.multiple
        XCTAssertEqual(2, try AWSCredentialsFileParser(string: file).parse().profiles.count)
    }

    func testThatMultipleFileContainsValidDefaultCredentials() throws {
        XCTAssertEqual(
            try AWSCredentialsFileParser(string: R.AWSCredentialsFile.multiple).parse()["default"],
            AWSCredentials.testDefault
        )
    }

    func testThatMultipleFileContainsValidMinioCredentials() throws {
        XCTAssertEqual(
            try AWSCredentialsFileParser(string: R.AWSCredentialsFile.multiple).parse()["minio"],
            AWSCredentials(accessKeyId: "minioadmin", secretKey: "minioadmin", region: "us-east-1")
        )
    }
}
