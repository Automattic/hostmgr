import Foundation
import ArgumentParser

struct VMCommand: AsyncParsableCommand {

    static var universalCommands: [ParsableCommand.Type] = [
        VMExistsCommand.self,
        VMFetchCommand.self,
        VMListCommand.self,
        VMStartCommand.self,
        VMStopCommand.self
    ]

    static var appleSiliconCommands: [ParsableCommand.Type] {
        #if arch(arm64)
        if #available(macOS 13.0, *) {
            return [
                VMCreateCommand.self,
                VMPackageCommand.self
            ]
        }
        #endif

        return []
    }

    static var intelCommands: [ParsableCommand.Type] {
        #if arch(x86_64)
        return [
            VMCleanCommand.self,
        ]
        #endif

        return []
    }

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: universalCommands + appleSiliconCommands + intelCommands
    )
}
