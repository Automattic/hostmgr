import Foundation
import ArgumentParser

struct SyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync remote data with this host",
        subcommands: [
            SyncAuthorizedKeysCommand.self,
            SyncVMImagesCommand.self,
        ]
    )

    @Flag(help: "List available sync tasks")
    var list: Bool = false

    @Argument
    var task: SchedulableSyncCommand?

    func run() throws {

        if let task = task {
            try perform(task: task)
            return
        }

        if list {
            SchedulableSyncCommand.allCases.forEach { print($0) }
            return
        }

        // Always regenerate the git mirror manifest – this is a lazy hack to make it so it doesn't need to be installed separately
        try GenerateGitMirrorManifestTask().run()

        try Configuration.shared.syncTasks.forEach { command in
            print("Running \(command.rawValue)")
            try perform(task: command)
        }
    }

    private func perform(task: SchedulableSyncCommand) throws {
        switch task {
            case .authorized_keys: try SyncAuthorizedKeysTask().run()
            case .vm_images: try SyncVMImagesTask().run()
        }
    }
}
