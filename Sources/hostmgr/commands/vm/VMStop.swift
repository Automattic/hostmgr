import Foundation
import ArgumentParser
import prlctl

struct VMStopCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stops a VM"
    )

    @Argument(help: "The Name or ID of the VM you'd like to stop")
    var virtualMachine: RunningVM?

    @Flag(help: "Kill the VM immediately, without waiting for it to shut down")
    var immediately: Bool = false

    @Flag(help: "Shutdown all VMs")
    var all: Bool = false

    func run() throws {
        try all ? shutdownAll() : virtualMachine?.shutdown()
    }

    private func shutdownAll() throws {
        try Parallels()
            .lookupRunningVMs()
            .forEach { try $0.shutdown(immediately: immediately) }
    }
}
