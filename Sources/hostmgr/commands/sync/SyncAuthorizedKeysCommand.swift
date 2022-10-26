import Foundation
import ArgumentParser
import SotoS3
import libhostmgr

struct SyncAuthorizedKeysCommand: AsyncParsableCommand, FollowsCommandPolicies {

    static let configuration = CommandConfiguration(
        commandName: Configuration.SchedulableSyncCommand.authorizedKeys.rawValue,
        abstract: "Set this machine's authorized_keys file"
    )

    @Option(
        name: .shortAndLong,
        help: "The S3 bucket containing the `authorized_keys` file"
    )
    var bucket: String = Configuration.shared.authorizedKeysBucket

    @Option(
        name: .shortAndLong,
        help: "The S3 region for the bucket"
    )
    var region: Region = Configuration.shared.authorizedKeysRegion

    @Option(
        name: .shortAndLong,
        help: "The S3 path to the authorized_keys file"
    )
    var key: String = "authorized_keys"

    @Option(
        name: .shortAndLong,
        help: "The path to your authorized_keys file on disk (defaults to ~/.ssh/authorized_keys)"
    )
    var destination: String = Configuration.shared.localAuthorizedKeys

    @OptionGroup
    var options: SharedSyncOptions

    static let commandIdentifier: String = "authorized-key-sync"

    /// A set of command policies that control the circumstances under which this command can be run
    static let commandPolicies: [CommandPolicy] = [
        .scheduled(every: 3600)
    ]

    func run() async throws {
        try to(evaluateCommandPolicies(), unless: options.force)

        logger.debug("Downloading file from s3://\(bucket)/\(key) in \(region) to \(destination)")
        logger.trace("Job schedule allows for running")

        let s3Manager = S3Manager(bucket: self.bucket, region: self.region.rawValue)

        guard let object = try await s3Manager.lookupObject(atPath: key) else {
            print("Unable to locate authorized_keys file – exiting")
            SyncAuthorizedKeysCommand.exit()
        }

        guard let bytes = try await s3Manager.download(object: object) else {
            print("Unable to download authorized_keys file – exiting")
            SyncAuthorizedKeysCommand.exit()
        }

        logger.trace("Downloaded \(bytes.count) bytes from S3")

        /// Create the parent directory if needed
        let parent = URL(fileURLWithPath: Configuration.shared.localAuthorizedKeys).deletingLastPathComponent()
        try FileManager.default.createDirectoryTree(atUrl: parent)

        /// Overwrite the existing file
        try bytes.write(to: URL(fileURLWithPath: destination))

        /// Fix the permissions on the file, if needed
        try FileManager.default.setAttributes([
            .posixPermissions: 0o600
        ], ofItemAtPath: destination)

        try recordLastRun()
    }
}
