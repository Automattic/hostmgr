import Foundation
import ArgumentParser
import libhostmgr

struct VMDetailsCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Shows information about a given VM"
    )

    @Argument(help: "The VM to fetch details for")
    var virtualMachine: String

    func run() throws {
        guard let virtualMachine = try ParallelsVMRepository().lookupVM(byIdentifier: self.virtualMachine) else {
            Console.crash(message: "There is no local VM named \(self.virtualMachine)", reason: .fileNotFound)
        }

        guard let runningVM = virtualMachine.asRunningVM() else {
            Console.crash(message: "There is no running VM named \(self.virtualMachine)", reason: .invalidVMStatus)
        }

        guard runningVM.hasIpV4Address else {
            Console.crash(message: "The VM \(self.virtualMachine) does not have an IP address", reason: .invalidVMStatus)
        }

        print("IPv4 Address:\t\(runningVM.ipAddress)")
    }
}
