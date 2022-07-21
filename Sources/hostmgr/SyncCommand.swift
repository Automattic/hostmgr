import Foundation
import ArgumentParser
import libhostmgr

struct SyncCommand: ParsableCommand {
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

    @Flag(help: "Force the job to run immediately, ignoring the schedule")
    var force: Bool = false

    @Argument
    var task: Configuration.SchedulableSyncCommand?

    func run() throws {

        if let task = task {
            try perform(task: task, immediately: force)
            return
        }

        if list {
            Configuration.SchedulableSyncCommand.allCases.forEach { print($0) }
            return
        }

        // Always regenerate the git mirror manifest – this is a lazy hack
        // to make it so it doesn't need to be installed separately
        try GenerateGitMirrorManifestTask().run()

        try Configuration.shared.syncTasks.forEach { command in
            force ? print("Force-running \(command.rawValue)") : print("Running \(command.rawValue)")
            try perform(task: command, immediately: self.force)
        }
    }

    private func perform(task: Configuration.SchedulableSyncCommand, immediately: Bool) throws {
        switch task {
        case .authorizedKeys:
            let command = SyncAuthorizedKeysCommand(force: immediately)
            try command.run()
        case .vmImages:
            let command = SyncVMImagesCommand(force: immediately)
            try command.run()
        }
    }
}
