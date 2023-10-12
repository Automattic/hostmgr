import XCTest
@testable import libhostmgr

final class VMResolverTests: XCTestCase {

    /// An ephemeral VM that will be destroyed on exit
    let workingVMPath = Paths.toWorkingAppleSiliconVM(named: "foo")

    /// A persistent VM that's not a template
    let bundleVMPath = Paths.toAppleSiliconVM(named: "foo")

    /// A VM template that can be duplicated as an ephemeral VM
    let templateVMPath = Paths.toVMTemplate(named: "foo")

    /// An archived VM that's packaged for upload or download
    let archivedVMPath = Paths.toArchivedVM(named: "foo")

    func testThatWorkingVMIsResolvedBeforeBundleVM() throws {
        let existingFiles = MockFileManager(existingDirectories: [
            bundleVMPath,
            workingVMPath,
        ])

        XCTAssertEqual(try VMResolver.resolvePath(for: "foo", fileManager: existingFiles), workingVMPath)
    }

    func testThatBundledVMIsResolvedBeforeTemplateVM() throws {
        let existingFiles = MockFileManager(existingDirectories: [
            templateVMPath,
            bundleVMPath,
        ])

        XCTAssertEqual(try VMResolver.resolvePath(for: "foo", fileManager: existingFiles), bundleVMPath)
    }

    func testThatTemplateVMIsResolvedBeforeArchivedVM() throws {
        let existingFiles = MockFileManager(existingFiles: [archivedVMPath], existingDirectories: [templateVMPath,])

        XCTAssertEqual(try VMResolver.resolvePath(for: "foo", fileManager: existingFiles), templateVMPath)
    }

    func testThatArchivedVMIsResolvable() throws {
        let existingFiles = MockFileManager(existingFiles: [archivedVMPath])
        XCTAssertEqual(try VMResolver.resolvePath(for: "foo", fileManager: existingFiles), archivedVMPath)
    }

    func testThatErrorIsThrownForUnresolvableVM() throws {
        XCTAssertThrowsError(try VMResolver.resolvePath(for: "foo", fileManager: MockFileManager()))
    }
}
