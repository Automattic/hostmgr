import Foundation
import ArgumentParser
import libhostmgr

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync remote data with this host",
        subcommands: [
            SyncAuthorizedKeysCommand.self
        ]
    )
}
