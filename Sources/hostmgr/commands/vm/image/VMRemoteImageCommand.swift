import Foundation
import ArgumentParser

struct VMRemoteImageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote",
        abstract: "Commands to work with remote images",
        subcommands: [
            VMRemoteImageDownload.self
        ]
    )
}
