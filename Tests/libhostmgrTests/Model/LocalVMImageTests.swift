import XCTest
@testable import libhostmgr

final class LocalVMImageTests: XCTestCase {

    func testThatVMNameIsProperlyExtractedFromVersionNumber() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.bundle"))
        XCTAssertEqual("macos-13.5.1", AppleSiliconVMImage(path: path)?.name)
    }

    func testThatVMNameIsProperlyExtractedFromVMTemplate() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.vmtemplate"))
        XCTAssertEqual("macos-13.5.1", AppleSiliconVMImage(path: path)?.name)
    }

    func testThatCompressedAppleSiliconImageIsDetectedAsArm64() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.vmtemplate.aar"))
        XCTAssertEqual("macos-13.5.1", AppleSiliconVMImage(path: path)?.name)
    }

    func testThatInvalidFileExtensionReturnsNil() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.vmbundle"))
        XCTAssertNil(AppleSiliconVMImage(path: path))
    }

    func testThatPackagedImageReturnsCorrectState() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.vmtemplate.aar"))
        XCTAssertEqual(AppleSiliconVMImage(path: path)?.state, .packaged)
    }

    func testThatVMTemplateReturnsCorrectState() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.vmtemplate"))
        XCTAssertEqual(AppleSiliconVMImage(path: path)?.state, .ready)
    }

    func testThatVMReturnsCorrectState() throws {
        let path = try XCTUnwrap(URL(filePath: "/opt/ci/vm-images/macos-13.5.1.bundle"))
        XCTAssertEqual(AppleSiliconVMImage(path: path)?.state, .ready)
    }
}
