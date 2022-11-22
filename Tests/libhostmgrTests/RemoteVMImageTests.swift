import XCTest
@testable import libhostmgr

final class RemoteVMImageTests: XCTestCase {

    private let testSubject = RemoteVMImage(
        imageObject: S3Object(key: "foo/bar.txt", size: 1234, modifiedAt: Date.distantPast),
        checksumKey: "foo/bar.sha1.txt"
    )

    func testThatImagePathIsValid() throws {
        XCTAssertEqual("foo/bar.txt", testSubject.imagePath)
    }

    func testThatFileNameIsValid() throws {
        XCTAssertEqual("bar.txt", testSubject.fileName)
    }

    func testThatBaseNameIsValid() throws {
        XCTAssertEqual("bar", testSubject.basename)
    }

    func testThatSizeCanBeRetrieved() throws {
        XCTAssertEqual(1234, testSubject.imageObject.size)
    }

    func testThatChecksumCanBeRetrieved() throws {
        XCTAssertEqual("foo/bar.sha1.txt", testSubject.checksumKey)
    }
}
