import Foundation
import ArgumentParser
import libhostmgr

struct GitMirrorPublishCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "publish-git-mirror",
        abstract: "Uploads the local git mirror for this project for use by other nodes"
    )

    @Option(
        help: "The URL to the Git repository that will be cached"
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

        guard try await !server.hasFile(named: gitMirror.remoteFilename) else {
            Console.exit("Remote mirror already exists – exiting", style: .error)
        }

        Console.info("Compressing \(gitMirror.localPath.path()) to \(gitMirror.archivePath)")
        try gitMirror.compress()

        // At the moment `service.uploadFile` does a multi-part upload, which fails if one of those batches is less
        // than 5 MB. Instead of implementing a direct upload in tinys3, we'll put a random minimal size limit (50 MB)
        // to git mirror files. If the file size is too small, git checkout should be pretty fast and it's okay to not
        // save the git repo in S3.
        let archiveSize = try FileManager.default.size(ofObjectAt: gitMirror.archivePath)
        let archiveSizeInMB = Measurement(value: Double(archiveSize), unit: UnitInformationStorage.bytes)
            .converted(to: .megabytes)
        if archiveSizeInMB.value < 50 {
            Console.info("Skipping uploading the git mirror because it is too small")
            return
        }

        let progress = Console.startProgress("Uploading mirror to \(gitMirror.remoteFilename)", type: .upload)
        try await server.uploadFile(
            at: gitMirror.archivePath,
            to: gitMirror.remoteFilename,
            // See https://github.com/Automattic/hostmgr/issues/102
            // For the case of git mirrors, since those are published by Buildkite jobs during `post-checkout`,
            // there isn't much sense in allowing resume for them anyway—as even if they fail on a given job,
            // that job won't re-run the `publish-git-mirror` command again on failure.
            allowResume: false,
            progress: progress.update
        )

        Console.success("Upload complete")
    }
}
