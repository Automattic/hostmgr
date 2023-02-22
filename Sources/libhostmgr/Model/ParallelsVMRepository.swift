import Foundation
import prlctl

public protocol ParallelsVMRepositoryProtocol {
    func lookupVMs() throws -> [VM]

    func lookupRunningVMs() throws -> [RunningVM]
    func lookupInvalidVMs() throws -> [InvalidVM]

    func lookupVM(withPrefix: String) throws -> VM?
    func lookupVM(byIdentifier id: String) throws -> VM?
}

public struct ParallelsVMRepository: ParallelsVMRepositoryProtocol {

    public init() {}

    public func lookupVMs() throws -> [VM] {
        try Parallels().lookupAllVMs()
    }

    public func lookupVMs(whereStatus status: VMStatus) throws -> [VM] {
        try lookupVMs().filter { $0.status == status }
    }

    public func lookupRunningVMs() throws -> [RunningVM] {
        try Parallels().lookupRunningVMs()
    }

    public func lookupInvalidVMs() throws -> [InvalidVM] {
        try Parallels().lookupInvalidVMs()
    }

    public func lookupVM(withPrefix prefix: String) throws -> VM? {
        return try Parallels()
            .lookupAllVMs()
            .filter { $0.name.hasPrefix(prefix) }
            .first
    }

    public func lookupVM(byIdentifier id: String) throws -> VM? {
        try Parallels()
            .lookupAllVMs()
            .first(where: { $0.name == id || $0.uuid == id })
    }

    public func unpack(localVM: LocalVMImage) async throws {

        guard let importedVirtualMachine = try Parallels().importVM(at: localVM.path) else {
            Console.crash(message: "Unable to import VM at: \(localVM.path)", reason: .unableToImportVM)
        }

        guard localVM.state == .packaged, let package = importedVirtualMachine.asPackagedVM() else {
            Console.crash(message: "VM \(localVM.basename) is not a packaged VM", reason: .invalidVMStatus)
        }

        Console.info("Unpacking \(package.name) – this will take a few minutes")
        let unpackedVM = try package.unpack()
        Console.success("Unpacked \(package.name)")

        // If we simply rename the `.pvmp` file, the underlying `pvm` file may retain its original name. We should
        // update the file on disk to reference this name
        if localVM.basename != unpackedVM.name {
            Console.info("Fixing Parallels VM Label")
            try unpackedVM.rename(to: localVM.basename)
            Console.success("Parallels VM Label Fixed")
        }

        Console.success("Finished Unpacking VM")

        Console.info("Cleaning Up")
        try unpackedVM.unregister()
        Console.success("Done")

    }

    public func startVM(named name: String) async throws {
        let startDate = Date()

        guard let sourceVM = try LocalVMRepository().lookupVM(withName: name) else {
            Console.crash(message: "VM \(name) could not be found", reason: .fileNotFound)
        }

        try resetVMStorage()

        if sourceVM.state == .packaged {
            try await unpack(localVM: sourceVM)
            return try await startVM(named: name)
        }

        let destination = Paths.ephemeralVMStorageDirectory.appendingPathComponent(name + ".tmp.pvm")

        try Paths.createEphemeralVMStorageIfNeeded()
        try FileManager.default.removeItemIfExists(at: destination)
        try FileManager.default.copyItem(at: sourceVM.path, to: destination)
        Console.info("Created temporary VM at \(destination)")

        guard let parallelsVM = try Parallels().importVM(at: destination)?.asStoppedVM() else {
            Console.crash(message: "Unable to import VM: \(destination)", reason: .unableToImportVM)
        }

        Console.success("Successfully Imported \(parallelsVM.name) with UUID \(parallelsVM.uuid)")

        try applyVMSettings([
            .memorySize(Int(ProcessInfo().physicalMemory / 1024 / 1024) - 4096),  // We should make this configurable
            .cpuCount(ProcessInfo().physicalProcessorCount),
            .hypervisorType(.apple),
            .networkType(.shared),
            .isolateVM(.on),
            .sharedCamera(.off)
        ], to: parallelsVM)

        try parallelsVM.start(wait: false)

        let _: Void = try await withCheckedThrowingContinuation { continuation in
            do {
                try waitForVMStartup(parallelsVM)
            } catch {
                continuation.resume(with: .failure(error))
                return
            }

            let elapsed = Date().timeIntervalSince(startDate)
            Console.success("Booted \(parallelsVM.name) \(Format.time(elapsed))")
            continuation.resume(with: .success(()))
        }
    }

    public func stopRunningVM(named name: String, immediately: Bool = true) async throws {
        let parallelsVM = try lookupParallelsVMOrExit(withIdentifier: name)

        guard let vmToStop = parallelsVM.asRunningVM() else {
            Console.exit(
                message: "\(parallelsVM.name) is not running, so it can't be stopped",
                style: .warning
            )
        }

        Console.info("Shutting down \(parallelsVM.name)")

        try vmToStop.shutdown(immediately: immediately)
        try vmToStop.unregister()

        // Clean up after ourselves by deleting the VM files
        let vmPath = FileManager.default.temporaryDirectory.appendingPathComponent(parallelsVM.name + ".tmp.pvm")

        guard try FileManager.default.directoryExists(at: vmPath) else {
            Console.success("Shutdown Complete")
            return
        }

        Console.info("Deleting VM storage from \(vmPath)")
        try FileManager.default.removeItem(at: vmPath)
    }

    public func stopAllRunningVMs(immediately: Bool = true) async throws {
        for parallelsVM in try self.lookupRunningVMs() {
            try await self.stopRunningVM(named: parallelsVM.name, immediately: immediately)
        }
    }

    private func waitForVMStartup(_ parallelsVirtualMachine: StoppedVM) throws {
        repeat {
            usleep(100_000)
        } while try Parallels()
            .lookupRunningVMs()
            .filter { $0.uuid == parallelsVirtualMachine.uuid && $0.hasIpV4Address }
            .isEmpty
    }

    private func lookupParallelsVMOrExit(withIdentifier id: String) throws -> VM {
        guard let parallelsVirtualMachine = try self.lookupVM(byIdentifier: id) else {
            Console.crash(
                message: "There is no VM with the name or UUID `\(id)` registered with Parallels",
                reason: .parallelsVirtualMachineDoesNotExist
            )
        }

        return parallelsVirtualMachine
    }

    private func applyVMSettings(_ settings: [StoppedVM.VMOption], to parallelsVM: StoppedVM) throws {
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
            try parallelsVM.set(setting)
        }

        // These are optional, and it's possible they've already been removed, so they may fail
        do {
            try parallelsVM.set(.withoutSoundDevice())
            try parallelsVM.set(.withoutCDROMDevice())
        } catch {
            Console.warn("Unable to remove device: \(error.localizedDescription)")
        }
    }
}
