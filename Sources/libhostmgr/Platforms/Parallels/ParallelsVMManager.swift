import Foundation
import Network
import prlctl

public struct ParallelsVMManager: VMManager {

    public typealias VM = ParallelsVMImage

    private let parallels: Parallels

    public init(parallels: Parallels) {
        self.parallels = parallels
    }

    public func startVM(name: String) async throws {
        try createWorkingDirectoriesIfNeeded()
        try await self.parallels.startVM(withHandle: name, wait: true)
    }

    public func stopVM(name: String) async throws {
        guard try await parallels.lookupVM(named: name)?.isRunningVM == true else {
            Console.exit(
                message: "\(name) is not running, so it can't be stopped",
                style: .warning
            )
        }

        Console.info("Shutting down \(name)")

        try await self.parallels.shutdownVM(withHandle: name, immediately: true)
        try await self.parallels.unregisterVM(named: name)

        if try await hasTempVM(named: name) {
            try await removeTempVM(name: name)
        }

        Console.success("Shutdown Complete")
    }

    public func stopAllRunningVMs() async throws {
        for vm in try await self.parallels.lookupRunningVMs() {
            try await stopVM(name: vm.name)
        }
    }

    public func removeVM(name: String) async throws {

    }

    public func waitForVMStartup(name: String) async throws {
        repeat {
            usleep(100_000)
        } while try await self.parallels
            .lookupRunningVMs()
            .filter { $0.name == name && $0.hasIpV4Address }
            .isEmpty
    }

    public func cloneVM(from source: String, to destination: String) async throws {
        try createWorkingDirectoriesIfNeeded()

        let sourcePath = Paths.vmImageStorageDirectory
            .appendingPathComponent(source)
            .appendingPathExtension(".pvm")

        let destinationFilePath = FileManager.default.temporaryFilePath(named: destination + ".tmp.pvm")
        try FileManager.default.removeItemIfExists(at: destinationFilePath)
        try FileManager.default.copyItem(at: sourcePath, to: destinationFilePath)
        Console.info("Created temporary VM at \(destinationFilePath)")

        guard let parallelsVM = try await self.parallels.importVM(at: destinationFilePath)?.asStoppedVM() else {
            Console.crash(message: "Unable to import VM: \(destination)", reason: .unableToImportVM)
        }

        Console.success("Successfully Imported \(parallelsVM.name) with UUID \(parallelsVM.uuid)")

        try await applyVMSettings([
            .memorySize(Int(ProcessInfo().physicalMemory / 1024 / 1024) - 4096),  // We should make this configurable
            .cpuCount(ProcessInfo().physicalProcessorCount),
            .hypervisorType(.apple),
            .networkType(.shared),
            .isolateVM(.on),
            .sharedCamera(.off)
        ], toVMWithName: destination)
    }

    public func applyVMSettings(_ settings: [VMOption], toVMWithName name: String) async throws {
        Console.info("Applying VM Settings")

        // Always leave 4GB available to the VM host – the VM can have the rest
        let dedicatedMemoryForVM = ProcessInfo().physicalMemory - (4096 * 1024 * 1024) // We should make this configurable
        let cpuCoreCount = ProcessInfo().physicalProcessorCount

        Console.printTable(data: [
            ["Total System Memory", Format.memoryBytes(ProcessInfo().physicalMemory)],
            ["VM System Memory", Format.memoryBytes(dedicatedMemoryForVM)],
            ["VM CPU Cores", "\(cpuCoreCount)"],
            ["Hypervisor Type", "apple"],
            ["Networking Type", "bridged"]
        ])

        for setting in settings {
            try await self.parallels.setVMOption(setting, onVirtualMachineWithHandle: name)
        }

        // These are optional, and it's possible they've already been removed, so they may fail
        do {
            try await self.parallels.setVMOption(.withoutCDROMDevice(), onVirtualMachineWithHandle: name)
            try await self.parallels.setVMOption(.withoutSoundDevice(), onVirtualMachineWithHandle: name)
        } catch {
            Console.warn("Unable to remove device: \(error.localizedDescription)")
        }
    }

    public func unpackVM(name: String) async throws {
        try createWorkingDirectoriesIfNeeded()

        let path = pathToPackagedVM(named: name)

        guard let importedVirtualMachine = try await self.parallels.importVM(at: path) else {
            Console.crash(message: "Unable to import VM at: \(path)", reason: .unableToImportVM)
        }

        guard importedVirtualMachine.status == .packaged, let package = importedVirtualMachine.asPackagedVM() else {
            Console.crash(message: "VM \(name) is not a packaged VM", reason: .invalidVMStatus)
        }

        let vmUUID = importedVirtualMachine.uuid

        Console.info("Unpacking \(package.name) – this will take a few minutes")
        try await self.parallels.unpackVM(withHandle: name)
        Console.success("Unpacked \(package.name)")

        // If we simply rename the `.pvmp` file, the underlying `pvm` file may retain its original name. We should
        // update the file on disk to reference this name
        Console.info("Fixing Parallels VM Label")
        try await self.parallels.renameVM(withHandle: vmUUID, to: name)
        Console.success("Parallels VM Label Fixed")

        Console.success("Finished Unpacking VM")

        Console.info("Cleaning Up")
        try await self.parallels.unregisterVM(named: name)
        Console.success("Done")
    }

    public func packageVM(name: String) async throws {
        // TODO
    }

    public func resetVMWorkingDirectory() async throws {
        try await removeAllTempVMs()
        try await removeAllRegisteredVMs()

        Console.success("Cleanup Complete")
    }

    public func ipAddress(forVmWithName name: String) async throws -> IPv4Address {
        guard let virtualMachine = try await self.parallels.lookupVM(named: name) else {
            Console.crash(message: "There is no local VM named \(name)", reason: .fileNotFound)
        }

        guard let runningVM = virtualMachine.asRunningVM() else {
            Console.crash(message: "There is no running VM named \(name)", reason: .invalidVMStatus)
        }

        let rawAddress = runningVM.ipAddress

        guard let address = IPv4Address(rawAddress) else {
            Console.crash(message: "VM \(name) has an invalid IP address", reason: .invalidVMStatus)
        }

        return address
    }
}

// MARK: On-Disk Storage
extension ParallelsVMManager {

    func removeTempVM(name: String) async throws {
        guard let path = try lookupTempVM(name: name)?.path else {
            Console.crash(message: "There is no VM named \(name)", reason: .fileNotFound)
        }

        Console.info("Removing temp VM file for \(name)")
        try FileManager.default.removeItem(at: path)
    }

    func removeAllTempVMs() async throws {
        for vm in try lookupTempVMs() {
            try await removeTempVM(name: vm.name)
        }
    }

    public func purgeUnusedImages() async throws {

    }

    private func pathToPackagedVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("pvmp")
    }

    private func pathToVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("pvm")
    }
}

// MARK: Internal Parallels Registry
extension ParallelsVMManager {
    func removeAllRegisteredVMs() async throws {
        for vm in try await self.parallels.lookupAllVMs() {
            Console.info("Removing Registered VM \(vm.name)")
            try await self.parallels.unregisterVM(named: vm.name)
        }
    }
}
