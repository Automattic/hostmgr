import Foundation
import ArgumentParser
import libhostmgr
import OSLog

@main
struct Hostmgr: AsyncParsableCommand {
    private static let appVersion = libhostmgr.hostmgrVersion

    static var configuration = CommandConfiguration(
        abstract: "A utility for managing VM hosts",
        version: appVersion,
        subcommands: [
            VMCommand.self,
            SyncCommand.self,
            InitCommand.self,
            InstallCommand.self,
            GenerateCommand.self,
            SetCommand.self,
            BenchmarkCommand.self,
            ConfigCommand.self,
            CacheCommand.self
        ]
    )

    mutating func run() async throws {
        Logger.cli.debug("Starting up")

        try Configuration.validate()

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
