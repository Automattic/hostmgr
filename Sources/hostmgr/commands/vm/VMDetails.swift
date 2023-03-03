import Foundation
import ArgumentParser
import libhostmgr

struct VMDetailsCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Shows information about a given VM"
    )

    @Argument(
        help: "The VM to fetch details for"
    )
    var name: String

    @Flag(help: "Show the VM's IPv4 address")
    var ipv4: Bool = false

    func run() async throws {
        #if arch(arm64)
        guard let tempFilePath = try LocalVMRepository().lookupVM(withName: name)?.path else {
            Console.crash(message: "There is no local VM called `\(name)`", reason: .fileNotFound)
        }
        let bundle = try VMBundle.fromExistingBundle(at: tempFilePath)
        guard let ipAddress = try bundle.currentIPaddress else {
            Console.crash(message: "Couldn't find an IP for `\(name)` – is it running?", reason: .invalidVMStatus)
        }

        Console.info("Waiting for SSH server to become available")
        try await VMLauncher.waitForSSHServer(forAddress: ipAddress)

        print("IPv4 Address:\t\(ipAddress)")

        #else
        if let virtualMachine = Parallels().lookupVM(named: self.name).asRunningVM() {
            if virtualMachine.hasIpV4Address {
                print("IPv4 Address:\t\(virtualMachine.ipAddress)")
            }
        }
        #endif
    }
}
