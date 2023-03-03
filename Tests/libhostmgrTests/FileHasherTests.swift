import XCTest
@testable import libhostmgr

final class FileHasherTests: XCTestCase {

    func testThatHasherProducesValidOutput() throws {
        XCTAssertEqual(
            "dad747aa4ba29546e6063f5c9fe6733594535db57f8f4450d27c06636e16beab",
            try FileHasher.stringRepresentationForHash(ofFileAt: pathForResource(named: "file-hasher-test-1"))
        )
    }

    func testThatHasherProducesValidOutputForLargeFile() throws {
        let filePath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createEmptyFile(at: filePath, size: .init(value: 25, unit: .megabytes))

        XCTAssertEqual(
            "9d210cdb0e23af9452f20801121ec965824e10988a54a640e622de1671a64229",
            try FileHasher.stringRepresentationForHash(ofFileAt: filePath)
        )
    }

    func testThatHasherThrowsForMissingFile() throws {
        XCTAssertThrowsError(try FileHasher.stringRepresentationForHash(ofFileAt: URL(fileURLWithPath: "/foo/bar/baz")))
    }
}
