import Foundation
import ArgumentParser
import SotoS3
import libhostmgr

struct SyncAuthorizedKeysCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "authorized_keys",
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

    func run() throws {
        try SyncAuthorizedKeysTask(bucket: bucket, region: region, key: key, destination: destination).run()
    }
}

struct SyncAuthorizedKeysTask {

    private let bucket: String
    private let region: Region
    private let key: String
    private let destination: String

    init(
        bucket: String = Configuration.shared.authorizedKeysBucket,
        region: Region = Configuration.shared.authorizedKeysRegion,
        key: String = "authorized_keys",
        destination: String = Configuration.shared.localAuthorizedKeys
    ) {
        self.bucket = bucket
        self.region = region
        self.key = key
        self.destination = destination
    }

    func run(force: Bool = false) throws {
        let state = State.get()

        logger.debug("Downloading file from s3://\(bucket)/\(key) in \(region) to \(destination)")

        guard state.shouldRun || force else {
            print("This job is not scheduled to run until \(state.nextRunTime)")
            return
        }

        logger.trace("Job schedule allows for running")

        guard let bytes = try S3Manager().getFileBytes(region: region, bucket: bucket, key: key) else {
            print("Unable to sync authorized_keys file – exiting")
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

        try State.set(state: State(lastRunAt: Date()))
    }

    struct State: Codable {
        private static let key = "authorized-key-sync-state"
        var lastRunAt: Date = Date.distantPast

        var shouldRun: Bool {
            Date() > nextRunTime
        }

        var nextRunTime: Date {
            let runInterval = TimeInterval(Configuration.shared.authorizedKeysSyncInterval)
            return self.lastRunAt.addingTimeInterval(runInterval)
        }

        static func get() -> State {
            (try? StateManager.load(key: key)) ?? State()
        }

        static func set(state: State) throws {
            try StateManager.store(key: key, value: state)
        }
    }
}
