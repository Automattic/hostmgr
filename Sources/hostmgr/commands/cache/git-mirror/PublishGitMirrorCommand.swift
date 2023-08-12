import Foundation
import ArgumentParser
import libhostmgr

struct PublishGitMirrorCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "publish-git-mirror",
        abstract: "Uploads the local git mirror for this project for use by other nodes"
    )

    @Option(
        help: "The URL to the Git repository that will be fetched"
    )
    var gitMirror: GitMirror?

    func run() async throws {

        let gitMirror = try self.gitMirror ?? GitMirror.fromEnvironment(key: "BUILDKITE_REPO")

        Console.info("Publishing the Git Mirror for \(gitMirror.url)")

        let s3Manager = try S3Manager(
            bucket: "a8c-repo-mirrors",
            region: "us-east-2",
            credentials: .fromUserConfiguration(),
            endpoint: .accelerated
        )

        guard try gitMirror.existsLocally else {
            Console.exit(message: "There is no local Git Mirror at \(gitMirror.localPath)", style: .error)
        }

        if let _ = try? await s3Manager.lookupObject(atPath: gitMirror.remoteFilename) {
            Console.exit(message: "Remote mirror already exists – exiting", style: .error)
        }

        Console.info("Compressing \(gitMirror.localPath)")
        try gitMirror.compress()

        let progress = Console.startProgress("Uploading mirror to \(gitMirror.remoteFilename)")

        try await s3Manager.upload(fileAt: gitMirror.archivePath, toKey: gitMirror.remoteFilename, progress: progress.update)

        Console.success("Upload complete")
    }
}
