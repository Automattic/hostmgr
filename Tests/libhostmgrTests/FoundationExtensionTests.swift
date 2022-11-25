import XCTest
@testable import libhostmgr

final class FoundationExtensionTests: XCTestCase {

    // MARK: FileManager Extensions
    func testThatFileExistsReturnsTrueForValidFile() throws {
        let path = try FileManager.default.createTemporaryFile(containing: "")
        XCTAssertTrue(FileManager.default.fileExists(at: path))
    }

    func testThatFileExistsReturnsFalseForInvalidFile() throws {
        XCTAssertFalse(FileManager.default.fileExists(at: URL(fileURLWithPath: UUID().uuidString)))
    }

    func testThatDirectoryExistsReturnsTrueForValidDirectory() throws {
        XCTAssertTrue(FileManager.default.directoryExists(at: FileManager.default.homeDirectoryForCurrentUser))
    }

    func testThatDirectoryExistsReturnsFalseForValidFile() throws {
        let path = try FileManager.default.createTemporaryFile(containing: "")
        XCTAssertFalse(FileManager.default.directoryExists(at: path))
    }

    func testThatDirectoryExistsReturnsFalseForInvalidPath() throws {
        XCTAssertFalse(FileManager.default.fileExists(at: URL(fileURLWithPath: UUID().uuidString)))
    }

    // MARK: NSRegularExpression Extensions
    func testThatRegularExpressionNamedMatchesCanBeFound() throws {
        let names = try NSRegularExpression(pattern: "^/s3/(?<bucketName>[^/]*)/(?<path>.*)").captureGroupNames
        XCTAssertEqual(["bucketName", "path"], names)
    }

    func testThatRegularExpressionNamedMatchesReturnEmptyArrayWhenNotFound() throws {
        let names = try NSRegularExpression(pattern: "^/s3/([^/]*)/(.*)").captureGroupNames
        XCTAssertTrue(names.isEmpty)
    }

    func testThatRegularExpressionNamedMatchesCanBeFoundInString() throws {
        let exp = try NSRegularExpression(pattern: "^/s3/(?<bucketName>[^/]*)")
        XCTAssertEqual(["bucketName": "my-bucket-name"], exp.namedMatches(in: "/s3/my-bucket-name/"))
    }
}
