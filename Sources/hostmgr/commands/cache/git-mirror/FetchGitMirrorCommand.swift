import Foundation
import ArgumentParser
import libhostmgr
import tinys3

struct FetchGitMirrorCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "fetch-git-mirror",
        abstract: "Downloads the most recent git mirror for this project"
    )

    @Option(
        help: "The URL to the Git repository that will be fetched"
    )
    var gitMirror: GitMirror?

    let cacheServer = CacheServer.gitMirrors

    enum CodingKeys: CodingKey{
        case gitMirror
    }

    func run() async throws {

        let gitMirror = try self.gitMirror ?? GitMirror.fromEnvironment(key: "BUILDKITE_REPO")

        if !FileManager.default.fileExists(at: gitMirror.archivePath) {
            Console.info("Fetching the Git Mirror for \(gitMirror.url)")

            if try await cacheServer.hasFile(atPath: gitMirror.remoteFilename) {
                Console.info("Downloading mirror from cache server")

                let progress = Console.startProgress("Downloading Git Mirror")
                try await cacheServer.downloadFile(
                    atPath: gitMirror.remoteFilename,
                    to: gitMirror.archivePath,
                    progress: progress.update
                )
            } else {
                Console.info("Downloading mirror from S3")
                let s3 = try S3Manager(
                    bucket: "a8c-repo-mirrors",
                    region: "us-east-2",
                    credentials: .fromUserConfiguration(),
                    endpoint: .accelerated
                )

                let objects = try await s3.listObjects(startingWith: gitMirror.slug)

                guard let mirrorToDownload = objects.sorted(using: KeyPathComparator(\.key, order: .reverse)).first else {
                    Console.exit(message: "No Git Mirrors found", style: .error)
                }

                let progress = Console.startProgress("Downloading Git Mirror")
                try await s3.download(key: mirrorToDownload.key, to: gitMirror.archivePath, progressCallback: progress.update)
            }

            Console.success("Download Complete")
        }

        if try !FileManager.default.directoryExists(at: gitMirror.localPath) {
            Console.info("Decompressing to \(Format.path(gitMirror.localPath))")
            try gitMirror.decompress()
        }

        Console.success("Git Mirror is ready")
    }
}
