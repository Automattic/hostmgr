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

    let servers: [ReadableRemoteFileProvider] = [
        CacheServer.gitMirrors,
        S3Server.gitMirrors
    ]

    enum CodingKeys: CodingKey {
        case gitMirror
    }

    /// Minimum valid archive size in bytes. Archives smaller than this are almost certainly corrupted
    /// or empty, since even a minimal git repo compresses to more than 1 KB.
    static let minimumArchiveSize = 1024

    func run() async throws {

        let gitMirror = try self.gitMirror ?? GitMirror.fromEnvironment(key: "BUILDKITE_REPO")

        if try !gitMirror.archiveExistsLocally {
            Console.info("Fetching the Git Mirror for \(gitMirror.url)")

            guard let server = try await servers.first(havingFileNamed: gitMirror.remoteFilename) else {
                Console.exit("No Git Mirror found for \(gitMirror.slug)", style: .error)
            }

            let progress = Console.startProgress("Downloading Git Mirror", type: .download)
            try await server.downloadFile(
                named: gitMirror.remoteFilename,
                to: gitMirror.archivePath,
                progress: progress.update
            )

            // Validate the downloaded archive is not empty or corrupted
            let archiveSize = try FileManager.default.size(ofObjectAt: gitMirror.archivePath)
            if archiveSize < Self.minimumArchiveSize {
                Console.error("Downloaded archive is too small (\(archiveSize) bytes) – removing corrupted file")
                try? FileManager.default.removeItemIfExists(at: gitMirror.archivePath)
                throw ExitCode.failure
            }

            Console.success("Download Complete")
        }

        if try !gitMirror.existsLocally {
            Console.info("Decompressing to \(Format.path(gitMirror.localPath))")
            do {
                try gitMirror.decompress()
            } catch {
                // Clean up the corrupted archive so that the next run will re-download from the
                // server instead of retrying the same bad file. The partial decompression output
                // is cleaned up by the defer block in GitMirror.decompress().
                Console.warn("Decompression failed – removing corrupted archive")
                try? FileManager.default.removeItemIfExists(at: gitMirror.archivePath)
                throw error
            }
        }

        Console.success("Git Mirror is ready")
    }
}
