import XCTest
import TSCBasic

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

    // MARK: ProcessInfo Extensions
    func testThatPhysicalProcessorCountIsValid() throws {
        let process = Process(args: "/usr/sbin/sysctl", "-n", "hw.physicalcpu")
        try process.launch()
        let count = try process.waitUntilExit().utf8Output().trimmingWhitespace

        XCTAssertEqual(Int(count), ProcessInfo.processInfo.physicalProcessorCount)
    }

    // MARK: String Extensions
    func testThatSlugifyProperlyTransformsURLs() throws {
        XCTAssertEqual(
            "https---github-com-kelseyhightower-nocode-git",
            "https://github.com/kelseyhightower/nocode.git".slugify()
        )
        XCTAssertEqual(
            "git-github-com-wordpress-mobile-WordPress-iOS-git",
            "git@github.com:wordpress-mobile/WordPress-iOS.git".slugify()
        )
    }
}
