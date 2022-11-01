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
        let importedVM = try await libhostmgr.importVM(name: name)

        Console.info("Applying VM Settings")

        // Always leave 4GB available to the VM host – the VM can have the rest
        let vmAvailableMemory = ProcessInfo().physicalMemory - (4096 * 1024 * 1024)
        let cpuCoreCount = ProcessInfo().physicalProcessorCount

        Console.printTable(data: [
            ["Total System Memory", Format.memoryBytes(ProcessInfo().physicalMemory)],
            ["VM System Memory", Format.memoryBytes(vmAvailableMemory)],
            ["VM CPU Cores", "\(cpuCoreCount)"],
            ["Hypervisor Type", "apple"],
            ["Networking Type", "bridged"]
        ])

        try [
            .memorySize(Int(vmAvailableMemory / 1024 / 1024)),
            .cpuCount(ProcessInfo().physicalProcessorCount),
            .hypervisorType(.apple),
            .networkType(.bridged),
            .isolateVM(.on),
            .sharedCamera(.off)
        ].forEach { try importedVM.set($0) }

        // These are optional, and it's possible they've already been removed, so they may fail
        do {
            try importedVM.set(.withoutSoundDevice())
            try importedVM.set(.withoutCDROMDevice())
        } catch {
            Console.warn("Unable to remove device: \(error.localizedDescription)")
        }

        try await libhostmgr.startVM(importedVM)
    }
}
