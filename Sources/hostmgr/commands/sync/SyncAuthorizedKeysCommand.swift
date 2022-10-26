import Foundation
import ArgumentParser
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
    var region: String = Configuration.shared.authorizedKeysRegion

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
        logger.debug("Job schedule allows for running")

        logger.info("Downloading file from s3://\(bucket)/\(key) in \(region) to \(destination)")

        let s3Manager = S3Manager(bucket: self.bucket, region: self.region)

        guard let object = try await s3Manager.lookupObject(atPath: key) else {
            print("Unable to locate authorized_keys file – exiting")
            SyncAuthorizedKeysCommand.exit()
        }

        let url = URL(fileURLWithPath: self.destination)
        try await s3Manager.download(object: object, to: url, progressCallback: nil)

        /// Fix the permissions on the file, if needed
        try FileManager.default.setAttributes([
            .posixPermissions: 0o600
        ], ofItemAtPath: self.destination)

        try recordLastRun()
    }
}
