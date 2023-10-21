import XCTest
@testable import libhostmgr

final class RemoteFileTests: XCTestCase {

    private let file1 = RemoteFile(size: 1234, path: "/foo/bar.baz", lastModifiedAt: .testDefault)
    private let file2 = RemoteFile(size: 1000, path: "/foo/baz.bar", lastModifiedAt: .testDefault)

    func testThatRemoteFileNameIsDerivedCorrectly() throws {
        XCTAssertEqual("bar.baz", file1.name)
    }

    func testThatRemoteFileBasenameIsDerivedCorrectly() throws {
        XCTAssertEqual("bar", file1.basename)
    }

    func testThatRemoteFilesAreOrderedCorrectly() throws {
        XCTAssertEqual(file1, [file1, file2].sorted().first)
    }
}
