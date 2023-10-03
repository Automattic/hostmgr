import Foundation
import Network
import prlctl

public struct ParallelsVMManager: VMManager {
    public typealias VM = ParallelsVMImage

    private let parallels: Parallels

    public init(parallels: Parallels) {
        self.parallels = parallels
    }

    public func startVM(configuration: LaunchConfiguration) async throws {
        try createWorkingDirectoriesIfNeeded()

        try await ensureLocalVMExists(named: configuration.name)

        guard !configuration.persistent else {
            try await self.parallels.startVM(withHandle: configuration.name)
            return
        }

        let tempName = configuration.name + "-" + UUID().uuidString
        try await cloneVM(from: configuration.name, to: tempName)
        try await self.parallels.startVM(withHandle: tempName, wait: true)
    }

    public func stopVM(name: String) async throws {
        guard try await parallels.lookupVM(named: name)?.isRunningVM == true else {
            Console.exit("\(name) is not running, so it can't be stopped", style: .warning)
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

        let destinationFilePath = Paths.toWorkingParallelsVM(named: destination)
        try FileManager.default.removeItemIfExists(at: destinationFilePath)
        try FileManager.default.copyItem(at: sourcePath, to: destinationFilePath)
        Console.info("Created temporary VM at \(destinationFilePath)")

        guard let parallelsVM = try await self.parallels.importVM(at: destinationFilePath)?.asStoppedVM() else {
            throw HostmgrError.unableToImportVM(destination)
        }

        Console.success("Successfully Imported \(parallelsVM.name) with UUID \(parallelsVM.uuid)")

        Console.printTable(data: [
            ["Total System Memory", Format.memoryBytes(ProcessInfo().physicalMemory)],
            ["VM System Memory", Format.memoryBytes(dedicatedMemoryForVM)],
            ["VM CPU Cores", "\(cpuCoreCount)"],
            ["Hypervisor Type", hypervisorType.rawValue],
            ["Networking Type", networkType.rawValue],
            ["VM Isolation", vmIsolation.rawValue],
            ["Camera Sharing", cameraSharing.rawValue]
        ])

        try await applyVMSettings([
            .memorySize(dedicatedMemoryForVM),
            .cpuCount(cpuCoreCount),
            .hypervisorType(hypervisorType),
            .networkType(networkType),
            .isolateVM(vmIsolation),
            .sharedCamera(cameraSharing)
        ], toVMWithName: destination)
    }

    public func applyVMSettings(_ settings: [VMOption], toVMWithName name: String) async throws {
        Console.info("Applying VM Settings")

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
            throw HostmgrError.unableToImportVM(name)
        }

        guard importedVirtualMachine.status == .packaged, let package = importedVirtualMachine.asPackagedVM() else {
            throw HostmgrError.vmIsNotPackaged(name)
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
            throw HostmgrError.localVMNotFound(name)
        }

        guard let runningVM = virtualMachine.asRunningVM() else {
            throw HostmgrError.vmIsNotRunning(name)
        }

        let rawAddress = runningVM.ipAddress

        guard let address = IPv4Address(rawAddress) else {
            throw HostmgrError.vmHasInvalidIpAddress(name)
        }

        return address
    }

    public func vmTemplateName(forVmWithName: String) async throws -> String? {
        nil
    }

    var dedicatedMemoryForVM: Int {
        Int(ProcessInfo().physicalMemory) - Configuration.shared.hostReservedRAM // We should make this configurable
    }

    let cpuCoreCount: Int = ProcessInfo.processInfo.physicalProcessorCount
    let hypervisorType: HypervisorType = .apple
    let networkType: NetworkType = .shared
    let vmIsolation: State = .on
    let cameraSharing: State = .off
}

// MARK: On-Disk Storage
extension ParallelsVMManager {

    func removeTempVM(name: String) async throws {
        guard let path = try lookupTempVM(name: name)?.path else {
            throw HostmgrError.localVMNotFound(name)
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
