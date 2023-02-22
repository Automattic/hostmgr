import XCTest
@testable import libhostmgr

final class PathsTests: XCTestCase {

    private var storageRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library").appendingPathComponent("Application Support").appendingPathComponent("com.automattic.hostmgr")
    }

    private func _p(_ string: String) -> String {
        storageRoot.appendingPathComponent(string).path
    }

    func testThatStorageRootIsCorrect() {
        validate(path: Paths.storageRoot, resolvesTo: "/usr/local/var", forArchitecture: .x64)
        validate(path: Paths.storageRoot, resolvesTo: storageRoot.path, forArchitecture: .arm64)
    }

    func testThatConfigurationRootIsCorrect() {
        validate(path: Paths.configurationRoot, resolvesTo: "/usr/local/etc/hostmgr", forArchitecture: .x64)
        validate(path: Paths.configurationRoot, resolvesTo: _p("configuration"), forArchitecture: .arm64)
    }

    func testThatStateRootIsCorrect() {
        validate(path: Paths.stateRoot, resolvesTo: "/usr/local/var/hostmgr/state", forArchitecture: .x64)
        validate(path: Paths.stateRoot, resolvesTo: _p("state"), forArchitecture: .arm64)
    }

    func testThatVMStoragePathIsCorrect() {
        validate(
            path: Paths.vmImageStorageDirectory,
            resolvesTo: "/usr/local/var/vm-images",
            forArchitecture: .x64
        )

        validate(
            path: Paths.vmImageStorageDirectory,
            resolvesTo: "/opt/homebrew/var/vm-images",
            forArchitecture: .arm64
        )
    }

    func testThatGitMirrorStoragePathIsCorrect() {
        let path = Paths.gitMirrorStorageDirectory
        validate(
            path: path,
            resolvesTo: "/usr/local/var/git-mirrors",
            forArchitecture: .x64
        )
        validate(
            path: path,
            resolvesTo: "/opt/homebrew/var/git-mirrors",
            forArchitecture: .arm64
        )
    }

    @available(macOS 13.0, *)
    func testThatAuthorizedKeysFilePathIsCorrect() {
        let resolvedPath = NSHomeDirectory() + "/.ssh/authorized_keys"
        validate(path: Paths.authorizedKeysFilePath, resolvesTo: resolvedPath)
    }

    func testThatConfigurationFilePathIsCorrect() {
        let path = Paths.configurationFilePath
        validate(path: path, resolvesTo: "/usr/local/etc/hostmgr/config.json", forArchitecture: .x64)
        validate(path: path, resolvesTo: _p("configuration/config.json"), forArchitecture: .arm64)
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
