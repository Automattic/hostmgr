import XCTest
@testable import libhostmgr
@testable import tinys3

final class RemoteVMImageTests: XCTestCase {
    private let testSubject = RemoteVMImage(
        imageFile: S3Object.with(
            key: "/foo/bar.vmtemplate.aar",
            size: 4096
        ).asFile
    )!

    func testThatInvalidKeyEmitsNilObject() throws {
        XCTAssertNil(RemoteVMImage(imageFile: S3Object.with(key: "/bar/baz", size: 0).asFile))
    }

    func testThatNameIsCorrect() throws {
        XCTAssertEqual("bar", testSubject.name)
    }

    func testThatfileNameIsCorrect() throws {
        XCTAssertEqual("bar.vmtemplate.aar", testSubject.fileName)
    }

    func testThatPathIsCorrect() throws {
        XCTAssertEqual("/foo/bar.vmtemplate.aar", testSubject.path)
    }

    func testThatSizeIsCorrect() throws {
        XCTAssertEqual(4096, testSubject.size)
    }
}
