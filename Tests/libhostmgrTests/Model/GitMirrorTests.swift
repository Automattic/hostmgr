import XCTest
@testable import libhostmgr

final class GitMirrorTests: XCTestCase {

    private let subject = GitMirror.from(string: "git@github.com:Automattic/hostmgr.git")!

    func testThatRemoteFilenameIsCorrect() throws {
        XCTAssertEqual(
            "git-github-com-Automattic-hostmgr-git-2023-08.aar",
            subject.calculateRemoteFilename(given: Date(timeIntervalSince1970: 1691801518))
        )
    }

    func testThatErrorIsThrownForMissingEnvironmentVariable() throws {
        XCTAssertThrowsError(try GitMirror.fromEnvironment(key: "foo"))
    }

    func testThatEnvironmentVariableIsDetectedCorrectly() throws {
        let environment = ["TEST_KEY": "git@github.com:Automattic/hostmgr.git"]
        XCTAssertNotNil(try GitMirror.fromEnvironment(key: "TEST_KEY", environment: environment))
    }

    func testThatErrorIsThrownIfEnvironmentVariableIsNotURL() throws {
        let environment = ["TEST_KEY": ""]
        XCTAssertThrowsError(try GitMirror.fromEnvironment(key: "TEST_KEY", environment: environment))
    }

    func testRemoveArchiveDeletesFile() throws {
        let archivePath = subject.archivePath
        try FileManager.default.createDirectory(
            at: archivePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: archivePath.path, contents: Data("test".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath.path))

        try subject.removeArchive()
        XCTAssertFalse(FileManager.default.fileExists(atPath: archivePath.path))
    }

    func testRemoveArchiveSucceedsWhenFileDoesNotExist() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: subject.archivePath.path))
        XCTAssertNoThrow(try subject.removeArchive())
    }
}
