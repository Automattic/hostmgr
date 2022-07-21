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

    @Option(
        help: "Clone type"
    )
    var depth: CloneType = .shallow

    func run() throws {

        let startDate = Date()

        try clone(vm: source, wait: wait || start, startDate: startDate, type: depth)

        guard let newVM = try Parallels().lookupVM(named: destination)?.asStoppedVM() else {
            print("Error finding cloned VM")
            VMCloneCommand.exit()
        }

        if !skipHostCustomization {

            let totalSystemMemory = Int(ProcessInfo().physicalMemory / (1024 * 1024)) // In MB
            let vmAvailableMemory = totalSystemMemory - 4096 // Always leave 4GB available to the VM host – the VM can have the rest
            let cpuCoreCount = ProcessInfo().physicalProcessorCount

            logger.debug("Total System Memory: \(totalSystemMemory) MB")
            logger.debug("Allocating \(vmAvailableMemory) MB to VM")
            try newVM.set(.memorySize(vmAvailableMemory))

            logger.debug("Allocating \(cpuCoreCount) cores to VM")
            try newVM.set(.cpuCount(cpuCoreCount))
        }

        logger.debug("Setting Hypervisor type to \(hypervisorType)")
        try newVM.set(.hypervisorType(hypervisorType))

        logger.debug("Setting Networking type to \(networkingType)")
        try newVM.set(.networkType(networkingType))

        if start {
            try startVM(vm: newVM, wait: wait, startDate: startDate)
        }
    }

    func clone(vm: StoppedVM, wait: Bool, startDate: Date, type: CloneType = .shallow) throws {
        try vm.clone(as: destination, fast: type.shouldUseFastClone)

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

    enum CloneType: String {
        /// Shallow clones are far faster and are most useful when the cloned VM will be discarded
        case shallow

        /// Deep clones are slower, but are easier to export as a new VM
        case full

        var shouldUseFastClone: Bool {
            switch self {
                case .shallow: return true
                case .full: return false
            }
        }
    }
}

extension StoppedVM.NetworkType: ExpressibleByArgument {}
extension StoppedVM.HypervisorType: ExpressibleByArgument {}
extension VMCloneCommand.CloneType: ExpressibleByArgument {}
