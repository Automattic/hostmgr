import XCTest
@testable import libhostmgr

#if arch(arm64)
final class VMTemplateTests: XCTestCase {

    func testThatManifestCanBeRead() throws {
        let url = FileManager.default.temporaryFilePath()
        let manifest = VMTemplate.ManifestFile(imageHash: Data(), auxilaryDataHash: Data())
        try manifest.write(to: url)

        XCTAssertEqual(try VMTemplate.ManifestFile.from(url: url), manifest)
    }
}
#endif
