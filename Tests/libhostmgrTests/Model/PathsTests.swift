import XCTest
@testable import libhostmgr

final class PathsTests: XCTestCase {

    func testThatStorageRootIsCorrect() {
        validate(path: Paths.storageRoot, resolvesTo: "/opt/ci", forArchitecture: .x64)
        validate(path: Paths.storageRoot, resolvesTo: "/opt/ci", forArchitecture: .arm64)
    }

    func testThatConfigurationRootIsCorrect() {
        validate(path: Paths.configurationRoot, resolvesTo: "/opt/ci", forArchitecture: .x64)
        validate(path: Paths.configurationRoot, resolvesTo: "/opt/ci", forArchitecture: .arm64)
    }

    func testThatStateRootIsCorrect() {
        validate(path: Paths.stateRoot, resolvesTo: "/opt/ci/hostmgr/state", forArchitecture: .x64)
        validate(path: Paths.stateRoot, resolvesTo: "/opt/ci/hostmgr/state", forArchitecture: .arm64)
    }

    func testThatVMStoragePathIsCorrect() {
        validate(path: Paths.vmImageStorageDirectory, resolvesTo: "/opt/ci/vm-images", forArchitecture: .x64)
        validate(path: Paths.vmImageStorageDirectory, resolvesTo: "/opt/ci/vm-images", forArchitecture: .arm64)
    }

    func testThatGitMirrorStoragePathIsCorrect() {
        let path = Paths.gitMirrorStorageDirectory
        validate(path: path, resolvesTo: "/opt/ci/git-mirrors", forArchitecture: .x64)
        validate(path: path, resolvesTo: "/opt/ci/git-mirrors", forArchitecture: .arm64)
    }

    func testThatAuthorizedKeysFilePathIsCorrect() {
        let resolvedPath = NSHomeDirectory() + "/.ssh/authorized_keys"
        validate(path: Paths.authorizedKeysFilePath, resolvesTo: resolvedPath)
    }

    func testThatConfigurationFilePathIsCorrect() {
        let path = Paths.configurationFilePath
        validate(path: path, resolvesTo: "/opt/ci/hostmgr.json", forArchitecture: .x64)
        validate(path: path, resolvesTo: "/opt/ci/hostmgr.json", forArchitecture: .arm64)
    }

    private func validate(
        path: URL,
        resolvesTo sample: String,
        forArchitecture arch: ProcessorArchitecture? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard arch != nil && arch == ProcessInfo.processInfo.processorArchitecture else {
            return
        }

        XCTAssertEqual(sample, path.path, file: file, line: line)
    }

}
