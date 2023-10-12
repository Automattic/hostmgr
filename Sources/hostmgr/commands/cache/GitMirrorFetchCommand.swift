import Foundation
import ArgumentParser
import libhostmgr
import tinys3

struct GitMirrorFetchCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "fetch-git-mirror",
        abstract: "Downloads the most recent git mirror for this project"
    )

    @Option(
        help: "The URL to the Git repository that will be fetched"
    )
    var gitMirror: GitMirror?

    let cacheServer = CacheServer.gitMirrors

    let servers: [ReadOnlyRemoteFileProvider] = [
//        CacheServer.gitMirrors,
        S3Server.gitMirrors
    ]

    enum CodingKeys: CodingKey {
        case gitMirror
    }

    func run() async throws {

        let gitMirror = try self.gitMirror ?? GitMirror.fromEnvironment(key: "BUILDKITE_REPO")

        if !FileManager.default.fileExists(at: gitMirror.archivePath) {
            Console.info("Fetching the Git Mirror for \(gitMirror.url)")

            guard let server = try await servers.first(havingFileAtPath: gitMirror.remoteFilename) else {
                Console.exit("No Git Mirror found for \(gitMirror.slug)", style: .error)
            }

            let progress = Console.startProgress("Downloading Git Mirror", type: .download)
            try await server.downloadFile(
                at: gitMirror.remoteFilename,
                to: gitMirror.archivePath,
                progress: progress.update
            )

            Console.success("Download Complete")
        }

        if try !FileManager.default.directoryExists(at: gitMirror.localPath) {
            Console.info("Decompressing to \(Format.path(gitMirror.localPath))")
            try gitMirror.decompress()
        }

        Console.success("Git Mirror is ready")
    }
}
