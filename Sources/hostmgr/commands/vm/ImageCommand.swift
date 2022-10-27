import Foundation
import ArgumentParser

struct VMImageCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Allows working with VM images",
        subcommands: [
            VMRemoteImageCommand.self
        ]
    )
}
