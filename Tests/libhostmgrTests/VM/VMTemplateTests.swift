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

}
