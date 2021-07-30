import Foundation
import ArgumentParser
import prlctl

struct VMCloneCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clone",
        abstract: "Clones a VM"
    )

    @Argument(
        help: "The name or UUID of the VM to clone"
    )
    var source: StoppedVM

    @Option(
        name: .shortAndLong,
        help: "The name of the new VM"
    )
    var destination: String

    @Flag(
        help: "Start the VM after cloning?"
    )
    var start: Bool = false

    @Flag(
        help: "Wait for the VM to finish cloning / booting?"
    )
    var wait: Bool = false

    func run() throws {

        let startDate = Date()

        try cloneVM(vm: source, wait: wait || start, startDate: startDate)

        if start {
            guard let newVM = try Parallels().lookupVM(named: destination)?.asStoppedVM() else {
                print("Error finding cloned VM")
                VMCloneCommand.exit()
            }

            try startVM(vm: newVM, wait: wait, startDate: startDate)
        }
    }

    func cloneVM(vm: StoppedVM, wait: Bool, startDate: Date) throws {
        try vm.clone(as: destination, fast: true)

        guard wait else {
            return
        }

        repeat {
            usleep(100)
        } while try Parallels().lookupVM(named: destination) == nil

        print(String(format: "VM cloned in %.2f seconds", Date().timeIntervalSince(startDate)))
    }

    func startVM(vm: StoppedVM, wait: Bool, startDate: Date) throws {

        try vm.start()

        guard wait else {
            return
        }

        repeat {
            usleep(100)
        } while try Parallels().lookupRunningVMs().filter { $0.uuid == vm.uuid && $0.hasIpV4Address }.isEmpty


        print(String(format: "VM cloned and booted in %.2f seconds", Date().timeIntervalSince(startDate)))
    }
}
