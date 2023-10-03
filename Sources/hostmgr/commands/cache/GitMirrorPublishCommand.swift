import Foundation
import ArgumentParser
import libhostmgr

struct GitMirrorPublishCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "publish-git-mirror",
        abstract: "Uploads the local git mirror for this project for use by other nodes"
    )

    @Option(
        help: "The URL to the Git repository that will be fetched"
    )
    var gitMirror: GitMirror?

    let server = S3Server.gitMirrors

    enum CodingKeys: CodingKey {
        case gitMirror
    }

    func run() async throws {

        let gitMirror = try self.gitMirror ?? GitMirror.fromEnvironment(key: "BUILDKITE_REPO")

        Console.info("Publishing the Git Mirror for \(gitMirror.url)")

        guard try gitMirror.existsLocally else {
            Console.exit("There is no local Git Mirror at \(gitMirror.localPath)", style: .error)
        }

        guard try await !server.hasFile(at: gitMirror.remoteFilename) else {
            Console.exit("Remote mirror already exists – exiting", style: .error)
        }

        Console.info("Compressing \(gitMirror.localPath)")
        try gitMirror.compress()

        let progress = Console.startProgress("Uploading mirror to \(gitMirror.remoteFilename)", type: .upload)
        try await server.uploadFile(at: gitMirror.archivePath, to: gitMirror.remoteFilename, progress: progress.update)

        Console.success("Upload complete")
    }
}
