import Foundation
import ArgumentParser

struct VMCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: [
            VMListCommand.self,
            VMStartCommand.self,
            VMStopCommand.self,
            VMDetailsCommand.self,
            VMCleanCommand.self,
            VMImageCommand.self,
            VMExistsCommand.self
        ]
    )
}
