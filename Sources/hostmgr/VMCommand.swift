import Foundation
import ArgumentParser

struct VMCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: [
            VMCleanCommand.self,
            VMCloneCommand.self,
            VMConnectCommand.self,
            VMCreateCommand.self,
            VMDetailsCommand.self,
            VMExistsCommand.self,
            VMFetchCommand.self,
            VMListCommand.self,
            VMPackageCommand.self,
            VMPublishCommand.self,
            VMStartCommand.self,
            VMStatsCommand.self,
            VMStopCommand.self
        ]
    )
}
