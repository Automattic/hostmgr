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

    private let startTime = Date()

    enum CodingKeys: CodingKey {
        case name
        case wait
    }

    func run() async throws {
        try await libhostmgr.startVM(name: self.name)

        guard wait else {
            return
        }

        #if arch(arm64)
        guard let tempFilePath = try LocalVMRepository().lookupVM(withName: name)?.path else {
            Console.crash(message: "There is no local VM called `\(name)`", reason: .fileNotFound)
        }

        guard let ipAddress = try VMBundle.fromExistingBundle(at: tempFilePath).currentIPaddress else {
            Console.crash(
                message: "Couldn't find an IP address for `\(name)` – is it running?",
                reason: .invalidVMStatus
            )
        }

        Console.info("Waiting for SSH server to become available")
        try await VMLauncher.waitForSSHServer(forAddress: ipAddress)
        Console.success("SSH server is available")

        Console.success("Startup Complete – Elapsed time: \(Format.elapsedTime(between: startTime, and: .now))")
        Console.info("You can access the VM using `ssh builder@\(ipAddress)`")
        #endif
    }
}
