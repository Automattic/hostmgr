import Foundation
import ArgumentParser

struct VMCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: [
            VMCleanCommand.self,
            VMDetailsCommand.self,
            VMExistsCommand.self,
            VMFetchCommand.self,
            VMListCommand.self,
            VMStartCommand.self,
            VMStopCommand.self,
        ]
    )
}
