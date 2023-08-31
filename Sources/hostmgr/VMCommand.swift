import Foundation
import ArgumentParser

struct VMCommand: AsyncParsableCommand {

    static var universalCommands: [ParsableCommand.Type] = [
        VMDetailsCommand.self,
        VMExistsCommand.self,
        VMFetchCommand.self,
        VMListCommand.self,
        VMStartCommand.self,
        VMStopCommand.self,
        VMPublish.self
    ]

    static var appleSiliconCommands: [ParsableCommand.Type] {
        #if arch(arm64)
        return [
            VMCreateCommand.self,
            VMPackageCommand.self
        ]
        #else
        return []
        #endif
    }

    static var intelCommands: [ParsableCommand.Type] {
        #if arch(x86_64)
        return [
            VMCleanCommand.self
        ]
        #else
        return []
        #endif
    }

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: universalCommands + appleSiliconCommands + intelCommands
    )
}
