import XCTest
@testable import libhostmgr

final class PathsTests: XCTestCase {

    private var storageRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("com.automattic.hostmgr")
    }

    private func _p(_ string: String) -> String {
        storageRoot.appendingPathComponent(string).path
    }

    func testThatStorageRootIsCorrect() {
        validate(path: Paths.storageRoot, resolvesTo: "/usr/local", forArchitecture: .x64)
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
        validate(path: Paths.vmImageStorageDirectory, resolvesTo: "/usr/local/var/vm-images", forArchitecture: .x64)
        validate(path: Paths.vmImageStorageDirectory, resolvesTo: _p("vm-images"), forArchitecture: .arm64)
    }

    func testThatGitMirrorStoragePathIsCorrect() {
        let path = Paths.gitMirrorStorageDirectory
        validate(path: path, resolvesTo: "/usr/local/var/git-mirrors", forArchitecture: .x64)
        validate(path: path, resolvesTo: _p("git-mirrors"), forArchitecture: .arm64)
    }

    func testThatAuthorizedKeysFilePathIsCorrect() {
        let resolvedPath = NSHomeDirectory() + "/.ssh/authorized_keys"
        validate(path: Paths.authorizedKeysFilePath, resolvesTo: resolvedPath)
    }

    func testThatConfigurationFilePathIsCorrect() {
        let path = Paths.configurationFilePath
        validate(path: path, resolvesTo: "/usr/local/etc/hostmgr/config.json", forArchitecture: .x64)
        validate(path: path, resolvesTo: _p("configuration/config.json"), forArchitecture: .arm64)
    }

    func testThatBuildkiteVMRootDirectoryIsCorrect() {
        let path = Paths.buildkiteVMRootDirectory(forUser: NSUserName())
        validate(path: path, resolvesTo: "/usr/local/var/buildkite-agent", forArchitecture: .x64)
        validate(path: path, resolvesTo: buildkiteRoot.path, forArchitecture: .arm64)
    }

    private var buildkiteRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    func _bp(_ path: String) -> String {
        buildkiteRoot.appendingPathComponent(path).path
    }

    func testThatBuildkiteBuildsDirectoryIsCorrect() {
        let path = Paths.buildkiteBuildDirectory(forUser: NSUserName())
        validate(path: path, resolvesTo: "/usr/local/var/buildkite-agent/builds", forArchitecture: .x64)
        validate(path: path, resolvesTo: _bp("builds"), forArchitecture: .arm64)
    }

    func testThatBuildkiteHooksDirectoryIsCorrect() {
        let path = Paths.buildkiteHooksDirectory(forUser: NSUserName())
        validate(path: path, resolvesTo: "/usr/local/var/buildkite-agent/hooks", forArchitecture: .x64)
        validate(path: path, resolvesTo: _bp("hooks"), forArchitecture: .arm64)
    }

    func testThatBuildkitePluginsDirectoryIsCorrect() {
        let path = Paths.buildkitePluginsDirectory(forUser: NSUserName())
        validate(path: path, resolvesTo: "/usr/local/var/buildkite-agent/plugins", forArchitecture: .x64)
        validate(path: path, resolvesTo: _bp("plugins"), forArchitecture: .arm64)
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
