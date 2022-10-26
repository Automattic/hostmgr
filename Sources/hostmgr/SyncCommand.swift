import Foundation
import ArgumentParser
import libhostmgr

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync remote data with this host",
        subcommands: [
            SyncAuthorizedKeysCommand.self,
            SyncVMImagesCommand.self
        ]
    )

    @Flag(help: "List available sync tasks")
    var list: Bool = false

    @OptionGroup
    var options: SharedSyncOptions

    mutating func run() async throws {

        if list {
            Configuration.SchedulableSyncCommand.allCases.forEach { print($0) }
            return
        }

        // Always regenerate the git mirror manifest – this is a lazy hack
        // to make it so it doesn't need to be installed separately
        try GenerateGitMirrorManifestTask().run()

        for task in Configuration.shared.syncTasks {
            options.force ? print("Force-running \(task.rawValue)") : print("Running \(task.rawValue)")
            try await perform(task: task)
        }
    }

    private func perform(task: Configuration.SchedulableSyncCommand) async throws {
        switch task {
        case .authorizedKeys:
            let command = SyncAuthorizedKeysCommand(options: self._options)
            try await command.run()
        case .vmImages:
            let command = SyncVMImagesCommand(options: self._options)
            try await command.run()
        }
    }
}
