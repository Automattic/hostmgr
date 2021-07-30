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
    var vm: VM

    @Flag(help: "Show the VM's IPv4 address")
    var ipv4: Bool = false

    func run() throws {
        if let vm = vm.asRunningVM() {
            if vm.hasIpV4Address {
                print("IPv4 Address:\t\(vm.ipAddress)")
            }
        }
    }
}
