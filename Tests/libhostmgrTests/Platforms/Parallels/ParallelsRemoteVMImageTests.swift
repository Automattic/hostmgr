import XCTest
@testable import libhostmgr
@testable import tinys3

final class ParallelsRemoteVMImageTests: XCTestCase {

    private let testSubject = ParallelsRemoteVMImage(imageFile: S3Object.with(key: "foo/bar.pvmp", size: 4096).asFile)!

    func testThatNameIsCorrect() throws {
        XCTAssertEqual("bar", testSubject.name)
    }

    func testThatfileNameIsCorrect() throws {
        XCTAssertEqual("bar.pvmp", testSubject.fileName)
    }

    func testThatPathIsCorrect() throws {
        XCTAssertEqual("foo/bar.pvmp", testSubject.path)
    }

    func testThatSizeIsCorrect() throws {
        XCTAssertEqual(4096, testSubject.size)
    }

    func testThatChecksumFilenameIsCorrect() throws {
        XCTAssertEqual("bar.sha256.txt", testSubject.checksumFileName)
    }

    func testThatChecksumPathIsCorrect() throws {
        XCTAssertEqual("/foo/bar.sha256.txt", testSubject.checksumPath)
    }
}
