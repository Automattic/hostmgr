import Foundation
import ArgumentParser
import prlctl

struct VMDetailsCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Shows information about a given VM"
    )

    @Argument(
        help: "The VM to fetch details for"
    )
    var virtualMachine: VM

    @Flag(help: "Show the VM's IPv4 address")
    var ipv4: Bool = false

    func run() throws {
        if let virtualMachine = virtualMachine.asRunningVM() {
            if virtualMachine.hasIpV4Address {
                print("IPv4 Address:\t\(virtualMachine.ipAddress)")
            }
        }
    }
}
