import Foundation
import ArgumentParser
import Logging
import libhostmgr

struct GenerateGitMirrorManifestCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "git-mirror-server-manifest",
        abstract: "Generate a git mirror server manifest"
    )

    func run() throws {
        try GenerateGitMirrorManifestTask().run()
    }
}

struct GenerateGitMirrorManifestTask {
    func run() throws {
        let paths = FileManager.default
            .subpaths(at: Configuration.shared.gitMirrorDirectory)

        let manifest = generateTextManifest(fromPaths: paths)

        try FileManager.default.createDirectoryTree(atUrl: Configuration.shared.gitMirrorDirectory)
        let manifestPath = Configuration.shared.gitMirrorDirectory.appendingPathComponent("manifest")
        try manifest.data(using: .utf8)?
            .write(to: manifestPath, options: .atomicWrite)
    }

    func generateTextManifest(fromPaths paths: [String]) -> String {
        paths
            .filter { $0.hasSuffix(".git.tar") } /// By using the `.git.tar` suffix, we avoid files that are currently being copied (which could look like: `2021-07-19.git.tar.e963f487`)
            .reduce([String: String](), flatten)
            .map { $0.key + $0.value }
            .sorted()
            .joined(separator: "\n")
    }

    func flatten(_ dict: [String: String], path: String) -> [String: String] {
        var dict = dict
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let key = path.replacingOccurrences(of: fileName, with: "")

        dict[key] = fileName

        return dict
    }

}
