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

    @Flag(
        help: "Don't customize the VM's CPU and memory for the physical host – retain its existing settings"
    )
    var skipHostCustomization: Bool = false

    @Option(
        help: "Hypervisor Type"
    )
    var hypervisorType: StoppedVM.HypervisorType = .apple

    @Option(
        help: "Networking Type"
    )
    var networkingType: StoppedVM.NetworkType = .bridged

    func run() throws {

        let startDate = Date()

        try cloneVM(vm: source, wait: wait || start, startDate: startDate)

        guard let newVM = try Parallels().lookupVM(named: destination)?.asStoppedVM() else {
            print("Error finding cloned VM")
            VMCloneCommand.exit()
        }

        if !skipHostCustomization {

            let totalSystemMemory = Int(ProcessInfo().physicalMemory / (1024 * 1024)) // In MB
            let vmAvailableMemory = totalSystemMemory - 4096 // Always leave 4GB available to the VM host – the VM can have the rest

            logger.debug("Total System Memory: \(totalSystemMemory) MB")
            logger.debug("Allocating \(vmAvailableMemory) MB to VM")

            let cpuCoreCount = ProcessInfo().physicalProcessorCount
            logger.debug("Allocating \(cpuCoreCount) cores to VM")

            try newVM.set(.cpuCount(cpuCoreCount))
            try newVM.set(.memorySize(vmAvailableMemory))
        }

        try newVM.set(.hypervisorType(hypervisorType))
        try newVM.set(.networkType(networkingType))

        if start {
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

extension StoppedVM.NetworkType: ExpressibleByArgument {}
extension StoppedVM.HypervisorType: ExpressibleByArgument {}
