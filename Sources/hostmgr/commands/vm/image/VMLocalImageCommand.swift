import Foundation
import ArgumentParser

struct VMLocalImageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "local",
        abstract: "Commands to work with local images",
        subcommands: [
            VMLocalImageListCommand.self
        ]
    )
}
