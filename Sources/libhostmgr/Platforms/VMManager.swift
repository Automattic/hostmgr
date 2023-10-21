import Foundation
import Network
import Virtualization

/// A protocol implementing a control layer for Virtual Machines – anything that you could do from a GUI, you should
/// be able to do with this protocol.
public struct VMManager {

    let vmUsageTracker = VMUsageTracker()

    public init() {}

    /// Start a VM
    ///
    public func startVM(configuration: LaunchConfiguration) async throws {
        try createWorkingDirectoriesIfNeeded()
        try await ensureLocalVMExists(named: configuration.name)
        try await vmUsageTracker.trackUsageOf(vmNamed: configuration.name)
        try await HostmgrClient.start(launchConfiguration: configuration)
    }

    /// Immediately terminate a VM
    /// 
    public func stopVM(handle: String) async throws {
        try await HostmgrClient.stop(handle: handle)
        try FileManager.default.removeItemIfExists(at: Paths.toWorkingAppleSiliconVM(named: handle))
    }

    /// Immediately terminates all running VMs
    public func stopAllRunningVMs() async throws {
        try await HostmgrClient.stopAllVMs()
        try resetVMWorkingDirectory()
    }

    /// Delete a local VM
    ///
    public func removeVM(name: String) async throws {
        try FileManager.default.removeItemIfExists(at: Paths.toAppleSiliconVM(named: name))
        try FileManager.default.removeItemIfExists(at: Paths.toArchivedVM(named: name))
        try FileManager.default.removeItemIfExists(at: Paths.toVMTemplate(named: name))
        try FileManager.default.removeItemIfExists(at: Paths.toWorkingAppleSiliconVM(named: name))
    }

    /// Unpack a packaged VM
    ///
    /// This method expects that the packaged VM is located in the `vm-images` directory – referencing it by name
    /// will attempt to unpack the VM at that location. If there is no packaged VM at that location, this method will
    /// emit an error.
    public func unpackVM(name: String) async throws {
        try Compressor.decompress(
            archiveAt: Paths.toArchivedVM(named: name),
            to: Paths.toVMTemplate(named: name)
        )

        try VMTemplate(at: Paths.toVMTemplate(named: name)).validate()
    }

    /// Package a VM for use on other machines
    ///
    /// This method expects that the VM to be packaged is a template located in the `vm-images` directory –
    /// referencing it by name will attempt to pack the VM in the directory with that name. If there is no VM at
    /// that location, an error will be emitted.
    public func packageVM(name: String) async throws {
        try Compressor.compress(
            directory: Paths.toVMTemplate(named: name),
            to: Paths.toArchivedVM(named: name)
        )
    }

    /// Resets the VM working directory by deleting any VMs that might have previously existed.
    ///
    /// This helps the node to be resilient against errors in the VM – if there's some
    /// consistent failure that prevents cleanup, we can ensure that the disk won't fill up.
    public func resetVMWorkingDirectory() throws {
        try FileManager.default.removeItemIfExists(at: Paths.vmWorkingStorageDirectory)
        try FileManager.default.createDirectory(at: Paths.vmWorkingStorageDirectory, withIntermediateDirectories: true)
    }

    /// Copy a VM template to a temporary location, making the VM ready for use
    ///
    /// - Parameters:
    ///   - from: The name of the VM template to copy. The VM template is expected to be located in
    ///   the `vm-images` directory. If there is no VM at that location, an error will be emitted.
    ///   - to: The name of the resulting VM
    public func cloneVM(source: String, destination: String) async throws {
        let bundle = try VMResolver.resolveBundle(named: source)
        _ = try bundle.createEphemeralCopy(at: Paths.toWorkingAppleSiliconVM(named: destination))
    }

    /// Wait for the VM with the given name to finish starting up
    ///
    public func waitForVMStartup(name: String, timeout: Duration = .seconds(30)) async throws {
        let address = try await ipAddress(forVmWithName: name)
        try await waitForSSHServer(forAddress: address, timeout: timeout)
    }

    /// Get details about a VM
    public func ipAddress(forVmWithName name: String) async throws -> IPv4Address {
        let vmBundle: VMResolver.Result = try VMResolver.resolve(name)

        switch vmBundle {
        case .bundle(let bundle): return try await ipAddress(for: bundle.macAddress)
        case .template(let template): return try await ipAddress(for: template.macAddress)
        }
    }

    /// Find the template for a given VM name
    public func vmTemplateName(forVmWithName name: String) async throws -> String? {
        switch try VMResolver.resolve(name) {
        case .bundle(let bundle): return try bundle.templateName
        case .template(let template): return template.basename
        }
    }

    /// Retrieve VMs that haven't been used since the given Date
    public func getVMImages(unusedSince cutoff: Date) async throws -> [VMUsageAggregate] {
        try await getVMUsageStats()
            .grouped()
            .unused(since: cutoff)
    }

    /// Retrieve usage stats for VMs
    public func getVMUsageStats() async throws -> [VMUsageRecord] {
        try await vmUsageTracker.usageStats()
    }
}

public extension VMManager {

    func list(sortedBy strategy: LocalVMImageSortingStrategy = .name) async throws -> [LocalVMImage] {
        try (lookupVMImages() + lookupTempVMs()).sorted(by: strategy.sortMethod)
    }

    func hasLocalVM(name: String, state: VMImageState) async throws -> Bool {
        try lookupVMImages().contains { $0.name == name && $0.state == state }
    }

    func hasTempVM(named name: String) async throws -> Bool {
        try lookupTempVMs().contains { $0.name == name }
    }

    func lookupVMImages() throws -> [LocalVMImage] {
        try resolveVMs(FileManager.default.children(ofDirectory: Paths.vmImageStorageDirectory))
    }

    func lookupTempVMs() throws -> [LocalVMImage] {
        try resolveVMs(FileManager.default.children(ofDirectory: Paths.vmWorkingStorageDirectory))
    }

    func lookupTempVM(name: String) throws -> LocalVMImage? {
        try lookupVMImages().first { $0.name == name }
    }

    func createWorkingDirectoriesIfNeeded() throws {
        try FileManager.default.createDirectoryIfNotExists(at: Paths.vmImageStorageDirectory)
        try FileManager.default.createDirectoryIfNotExists(at: Paths.vmWorkingStorageDirectory)
    }

    private func resolveVMs(_ paths: [URL]) -> [LocalVMImage] {
        paths.compactMap { LocalVMImage(path: $0) }
    }
}

extension VMManager {
    func ensureLocalVMExists(named name: String) async throws {
        guard try await hasLocalVM(name: name, state: .ready) else {
            throw HostmgrError.localVMNotFound(name)
        }
    }

    func ipAddress(for macAddress: VZMACAddress) async throws -> IPv4Address {
        var tries = 0

        repeat {
            do {
                return try DHCPLease.mostRecentLease(forMACaddress: macAddress).ipAddress
            } catch {
                try await Task.sleep(for: .seconds(1))
                tries += 1
            }
        } while(tries < 25)

        return try DHCPLease.mostRecentLease(forMACaddress: macAddress).ipAddress
    }

    func waitForSSHServer(forAddress address: IPv4Address, timeout: Duration) async throws {
        let connection = NWConnection(to: .hostPort(host: .ipv4(address), port: 22), using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = {newState in
                switch newState {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: CocoaError(.serviceRequestTimedOut))
                default:
                    break
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + TimeInterval(timeout.components.seconds)) {
                connection.cancel()
            }

            connection.start(queue: .main)
        }
    }
}
