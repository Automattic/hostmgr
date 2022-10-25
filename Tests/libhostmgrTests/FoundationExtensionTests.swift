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
        XCTAssertTrue(try FileManager.default.directoryExists(at: FileManager.default.homeDirectoryForCurrentUser))
    }

    func testThatDirectoryExistsReturnsFalseForValidFile() throws {
        let path = try FileManager.default.createTemporaryFile(containing: "")
        XCTAssertFalse(try FileManager.default.directoryExists(at: path))
    }

    func testThatDirectoryExistsReturnsFalseForInvalidPath() throws {
        XCTAssertFalse(FileManager.default.fileExists(at: URL(fileURLWithPath: UUID().uuidString)))
    }
}
