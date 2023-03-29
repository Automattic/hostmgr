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
        let manifest = try gitMirrorsManifest()

        try FileManager.default.createDirectory(
            at: Paths.gitMirrorStorageDirectory,
            withIntermediateDirectories: true
        )

        let manifestPath = Paths.gitMirrorStorageDirectory.appendingPathComponent("manifest")
        try manifest.data(using: .utf8)?
            .write(to: manifestPath, options: .atomicWrite)
    }

}
