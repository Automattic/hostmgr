import Foundation
import ArgumentParser
import libhostmgr
import tinys3

struct SyncAuthorizedKeysCommand: AsyncParsableCommand, FollowsCommandPolicies {

    enum Constants {
        static let s3Key = "authorized_keys"
    }

    static let configuration = CommandConfiguration(
        commandName: Configuration.SchedulableSyncCommand.authorizedKeys.rawValue,
        abstract: "Set this machine's authorized_keys file"
    )

    @OptionGroup
    var options: SharedSyncOptions

    let commandIdentifier: String = "authorized-key-sync"

    // A set of command policies that control the circumstances under which this command can be run
    let commandPolicies: [CommandPolicy] = [
        .scheduled(every: 3600)
    ]

    let server = S3Server.secrets

    enum CodingKeys: CodingKey {
        case options
    }

    func run() async throws {
        let destination = Paths.authorizedKeysFilePath

        try to(evaluateCommandPolicies(), unless: options.force)

        Console.heading("Syncing Authorized Keys")

        guard try await server.hasFile(at: Constants.s3Key) else {
            Console.error("Unable to locate authorized_keys file – exiting")
            throw ExitCode(rawValue: 1)
        }

        let progressBar = Console.startProgress("Downloading `authorized_keys`", type: .download)
        try await server.downloadFile(at: Constants.s3Key, to: destination, progress: progressBar.update)

        // Fix the permissions on the file, if needed
        Console.info("Setting file permissions on \(destination)")
        try FileManager.default.setAttributes([
            .posixPermissions: 0o600
        ], ofItemAt: destination)
        Console.success("Authorized Key Sync Complete")

        try recordLastRun()
    }
}
