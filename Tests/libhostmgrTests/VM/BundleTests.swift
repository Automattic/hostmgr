import XCTest
@testable import libhostmgr

class BundleTests: XCTestCase {

    struct BundleObject: libhostmgr.Bundle {
        var root: URL { URL(fileURLWithPath: "/tmp") }
    }

    func testThatRootIsStoredCorrectly() throws {
        XCTAssertEqual(BundleObject().root, URL(fileURLWithPath: "/tmp"))
    }

    func testThatImageFileIsAlwaysNamedCorrectly() throws {
        XCTAssertEqual(BundleObject().diskImageFilePath, URL(fileURLWithPath: "/tmp/image.img"))
    }

    func testThatAuxilaryImageFileIsAlwaysNamedCorrectly() throws {
        XCTAssertEqual(BundleObject().auxImageFilePath, URL(fileURLWithPath: "/tmp/aux.img"))
    }

    func testThatConfigurationFileIsAlwaysNamedCorrectly() throws {
        XCTAssertEqual(BundleObject().configurationFilePath, URL(fileURLWithPath: "/tmp/config.json"))
    }

    func testThatConfigurationFileIsExternallyReferencedProperly() throws {
        XCTAssertEqual(BundleObject.configurationFilePath(for: BundleObject().root), URL(fileURLWithPath: "/tmp/config.json"))
    }
}

class TemplateTests: BundleTests {
    struct BundleObject: TemplateBundle {
        var root: URL { URL(fileURLWithPath: "/tmp") }
    }

    func testThatManifestFileIsAlwaysNamedCorrectly() throws {
        XCTAssertEqual(BundleObject().manifestFilePath, URL(fileURLWithPath: "/tmp/manifest.json"))
    }
}
