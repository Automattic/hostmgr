import Foundation
import ArgumentParser
import libhostmgr
import tinys3

struct SyncAuthorizedKeysCommand: AsyncParsableCommand, FollowsCommandPolicies {

    struct Constants {
        static let s3Key = "authorized_keys"
        static let destination = Configuration.shared.localAuthorizedKeys
    }

    static let configuration = CommandConfiguration(
        commandName: Configuration.SchedulableSyncCommand.authorizedKeys.rawValue,
        abstract: "Set this machine's authorized_keys file"
    )

    @OptionGroup
    var options: SharedSyncOptions

    static let commandIdentifier: String = "authorized-key-sync"

    /// A set of command policies that control the circumstances under which this command can be run
    static let commandPolicies: [CommandPolicy] = [
        .scheduled(every: 3600)
    ]

    func run() async throws {
        try to(evaluateCommandPolicies(), unless: options.force)

        Console.heading("Syncing Authorized Keys")

        guard let credentials = try AWSCredentials.fromUserConfiguration() else {
            Console.crash(message: "Unable to find AWS Credentials", reason: .fileNotFound)
        }

        let s3Manager = try S3Manager(
            bucket: Configuration.shared.authorizedKeysBucket,
            region: Configuration.shared.authorizedKeysRegion,
            credentials: credentials,
            endpoint: .accelerated
        )

        guard let object = try await s3Manager.lookupObject(atPath: Constants.s3Key) else {
            Console.error("Unable to locate authorized_keys file – exiting")
            throw ExitCode(rawValue: 1)
        }

        let progressBar = Console.startFileDownload(object)

        try await s3Manager.download(
            key: object.key,
            to: URL(fileURLWithPath: Constants.destination),
            progressCallback: progressBar.update
        )

        /// Fix the permissions on the file, if needed
        Console.info("Setting file permissions on \(Constants.destination)")
        try FileManager.default.setAttributes([
            .posixPermissions: 0o600
        ], ofItemAtPath: Constants.destination)
        Console.success("Authorized Key Sync Complete")

        try recordLastRun()
    }
}
