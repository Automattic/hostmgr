import XCTest
@testable import libhostmgr

final class FileHasherTests: XCTestCase {

    func testThatHasherProducesValidOutput() throws {
        XCTAssertEqual(
            "ec0c6ed506b8eb9d84921aa757dc162ca7b318a3cc2dc93df7d5ad8339edf1e1",
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
