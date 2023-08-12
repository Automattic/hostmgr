import Foundation
import ArgumentParser

struct CacheCommand: AsyncParsableCommand {

    static var subcommands: [any ParsableCommand.Type] {

        if #available(macOS 13.0, *) {
            return [
                FetchGitMirrorCommand.self,
                PublishGitMirrorCommand.self
            ]
        } else {
            return []
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "cache",
        subcommands: CacheCommand.subcommands
    )
}
