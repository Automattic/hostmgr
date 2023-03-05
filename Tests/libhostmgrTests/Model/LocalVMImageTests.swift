import XCTest
@testable import libhostmgr

final class LocalVMImageTests: XCTestCase {

    func testThatCompressedAppleSiliconImageIsDetectedAsArm64() {
        XCTAssertEqual(LocalVMImage(path: URL(fileURLWithPath: "/test.vmpackage.aar"))?.architecture, .arm64)
    }

    func testThatCompressedIntelImageIsDetected() {
        XCTAssertEqual(LocalVMImage(path: URL(fileURLWithPath: "/test.pvmp.aar"))?.architecture, .x64)
    }

    func testThatCompressedAppleSiliconImageWithoutVMPackageExtensionPrefixIsInvalid() {
        XCTAssertNil(LocalVMImage(path: URL(fileURLWithPath: "/test.aar")))
    }

    func testThatPackagedAppleSiliconImageIsDetectedAsArm64() {
        XCTAssertEqual(LocalVMImage(path: URL(fileURLWithPath: "/test.vmtemplate"))?.architecture, .arm64)
    }

    func testThatBundlesWithXcodeMinorVersionIsParsedCorrectly() {
        XCTAssertEqual(
            LocalVMImage(path: URL(fileURLWithPath: "/xcode-14.3.bundle"))?.basename,
            "xcode-14.3"
        )
    }

    func testThatPackageWithXcodeMinorVersionIsParsedCorrectly() {
        XCTAssertEqual(
            LocalVMImage(path: URL(fileURLWithPath: "/xcode-14.3.vmpackage.aar"))?.basename,
            "xcode-14.3"
        )
    }
}
