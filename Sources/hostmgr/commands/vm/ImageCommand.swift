import Foundation
import ArgumentParser
import prlctl

struct VMImageCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Allows working with VM images",
        subcommands: [
            VMLocalImageCommand.self,
            VMRemoteImageCommand.self
        ]
    )
}
