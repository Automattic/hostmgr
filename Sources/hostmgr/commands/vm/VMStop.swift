import Foundation
import ArgumentParser
import libhostmgr

struct VMStopCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stops a VM"
    )

    @Argument(help: "The Name or ID of the VM you'd like to stop")
    var identifier: String?

    @Flag(help: "Kill the VM immediately, without waiting for it to shut down")
    var immediately: Bool = false

    @Flag(help: "Shutdown all VMs")
    var all: Bool = false

    func run() throws {

        if all {
            try libhostmgr.stopAllRunningVMs(immediately: self.immediately)
            Console.exit()
        }

        // In the case of invalid input like this, show the help text
        guard let identifier else {
            throw CleanExit.helpRequest()
        }

        try libhostmgr.stopRunningVM(name: identifier, immediately: immediately)
    }
}
