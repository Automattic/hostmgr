import Foundation
import ArgumentParser
import libhostmgr

struct VMStartCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Starts a VM"
    )

    @Argument
    var name: String

    @Flag(help: "Wait for the machine to finish starting up?")
    var wait: Bool = false

    func run() async throws {
        try await libhostmgr.startVM(name: self.name)
        try await StatsRepository().recordResourceUsage(for: self.name, category: .virtualMachine)
    }
}
