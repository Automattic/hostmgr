import XCTest
@testable import libhostmgr

@available(macOS 13.0, *)
final class VMTemplateTests: XCTestCase {

    func testThatNamedVMIsResolved() throws {
        XCTAssertEqual(
            VMTemplate(named: "foo").root,
            Paths.vmImageStorageDirectory.appendingPathComponent("foo.vmtemplate")
        )
    }

    func testThatManifestCanBeRead() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let manifest = VMTemplate.ManifestFile(imageHash: Data(), auxilaryDataHash: Data())
        try manifest.write(to: url)

        XCTAssertEqual(try VMTemplate.ManifestFile.from(url: url), manifest)
    }
}
