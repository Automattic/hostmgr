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

        guard wait else {
            return
        }

        debugPrint("Waiting for VM to boot")
        try await VMResolver.resolve()
        debugPrint("VM is booted")

        let hostname = try await VMHostnameResolver.resolve()
        debugPrint("ssh builder@\(hostname)")
    }
}
