import Foundation
import ArgumentParser
import libhostmgr

struct VMDetailsCommand: ParsableCommand {

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

    func run() throws {
        let parallelsVM = try libhostmgr.lookupParallelsVMOrExit(withIdentifier: self.name)

        var data = [
            ["Name:", parallelsVM.name],
            ["UUID:", parallelsVM.uuid],
            ["Status:", parallelsVM.status.rawValue.capitalized]
        ]

        if let runningVM = parallelsVM.asRunningVM(), runningVM.hasIpAddress {
            data.append(["IPv4 Address", runningVM.ipAddress])
        }

        Console.printTable(data: data)
    }
}
