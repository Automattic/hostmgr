import Foundation
import ArgumentParser
import libhostmgr

struct VMStopCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stops a VM"
    )

    @Argument(help: "The Name, ID, or Handle of the VM you'd like to stop")
    var identifier: String?

    @Flag(help: "Shutdown all VMs")
    var all: Bool = false

    let vmManager = VMManager()

    enum CodingKeys: CodingKey {
        case identifier
        case all
    }

    func run() async throws {

        guard all == false else {
            try await vmManager.stopAllRunningVMs()
            Console.exit()
        }

        // In the case of invalid input like this, show the help text
        guard let identifier else {
            throw CleanExit.helpRequest()
        }

        try await vmManager.stopVM(handle: identifier)
    }
}
