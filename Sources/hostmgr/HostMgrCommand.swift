import Foundation
import ArgumentParser
import Logging
import libhostmgr

@main
struct Hostmgr: AsyncParsableCommand {

    private static var appVersion = "0.20.0-rc-4"

    static var configuration = CommandConfiguration(
        abstract: "A utility for managing VM hosts",
        version: appVersion,
        subcommands: [
            VMCommand.self,
            SyncCommand.self,
            InitCommand.self,
            RunCommand.self,
            SetCommand.self,
            BenchmarkCommand.self,
            ConfigCommand.self
        ] + appleSiliconCommands
    )

    static var appleSiliconCommands: [ParsableCommand.Type] {
        #if arch(arm64)
        return [
            InstallCommand.self
        ]
        #else
        return []
        #endif
    }

    mutating func run() async throws {
        Logger.initializeLoggingSystem()

        logger.trace("Starting Up")

        guard Configuration.isValid else {
            print("Invalid configuration – exiting")
            throw ExitCode(1)
        }

        throw CleanExit.helpRequest(self)
    }
}

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set system values",
        subcommands: [
            SetAutomaticLoginPasswordCommand.self
        ]
    )
}

struct InstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install components",
        subcommands: [
            InstallHostmgrHelperCommand.self
        ]
    )
}

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a configuration file"
    )

    func run() throws {
        try FileManager.default.createDirectory(at: Paths.gitMirrorStorageDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: Paths.vmImageStorageDirectory, withIntermediateDirectories: true)
    }
}
