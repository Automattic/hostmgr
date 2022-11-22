import XCTest
@testable import libhostmgr
@testable import tinys3

final class RemoteVMImageTests: XCTestCase {

    private let testSubject = RemoteVMImage(
        imageObject: S3Object(
            key: "foo/bar.txt",
            size: 1234,
            eTag: "",
            lastModifiedAt: Date.distantPast,
            storageClass: ""
        ),
        checksumObject: S3Object(
            key: "foo/bar.sha1.txt",
            size: 64,
            eTag: "",
            lastModifiedAt: Date.distantPast,
            storageClass: ""
        )
    )

    func testThatImagePathIsValid() throws {
        XCTAssertEqual("foo/bar.txt", testSubject.imageObject.key)
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
        XCTAssertEqual("foo/bar.sha1.txt", testSubject.checksumObject.key)
    }
}
