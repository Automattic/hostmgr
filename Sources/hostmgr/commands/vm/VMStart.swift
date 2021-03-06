import Foundation
import ArgumentParser
import prlctl

struct VMStartCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Starts a VM"
    )

    @Argument
    var virtualMachine: StoppedVM

    @Flag(help: "Wait for the machine to finish starting up?")
    var wait: Bool = false

    func run() throws {
        let startDate = Date()

        try virtualMachine.start()

        guard wait else {
            return
        }

        repeat {
            usleep(100)
        } while try Parallels()
            .lookupRunningVMs()
            .filter { $0.uuid == virtualMachine.uuid && $0.hasIpAddress }
            .isEmpty

        let elapsed = Date().timeIntervalSince(startDate)
        print(String(format: "System booted in %.2f seconds", elapsed))
    }
}
