import Foundation
import ArgumentParser

struct VMCommand: AsyncParsableCommand {

    static var universalCommands: [ParsableCommand.Type] = [
        VMCleanCommand.self,
        VMExistsCommand.self,
        VMFetchCommand.self,
        VMListCommand.self,
        VMStartCommand.self,
        VMStopCommand.self
    ]

    static var appleSiliconCommands: [ParsableCommand.Type] {
        if #available(macOS 13.0, *) {
            return [
                VMCreateCommand.self,
                VMPackageCommand.self
            ]
        }

        return []
    }

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: universalCommands + appleSiliconCommands
    )
}
