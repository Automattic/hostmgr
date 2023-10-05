import Foundation
import Network
import Virtualization

struct AppleSiliconVMManager: VMManager {    
    typealias VM = AppleSiliconVMImage

    let vmUsageTracker = VMUsageTracker()

    func startVM(configuration: LaunchConfiguration) async throws {
        try createWorkingDirectoriesIfNeeded()
        try await ensureLocalVMExists(named: configuration.name)
        try await vmUsageTracker.trackUsageOf(vm: configuration.name)
        try await HostmgrXPCService.startVM(withLaunchConfiguration: configuration)
    }

    func stopVM(handle: String) async throws {
        try await HostmgrXPCService.stopVM(handle: handle)
        try FileManager.default.removeItemIfExists(at: Paths.toWorkingAppleSiliconVM(named: handle))
    }

    func stopAllRunningVMs() async throws {
        try await HostmgrXPCService.stopAllVMs()
    }

    func removeVM(name: String) async throws {
        try FileManager.default.removeItemIfExists(at: Paths.toAppleSiliconVM(named: name))
        try FileManager.default.removeItemIfExists(at: Paths.toArchivedVM(named: name))
        try FileManager.default.removeItemIfExists(at: Paths.toVMTemplate(named: name))
        try FileManager.default.removeItemIfExists(at: Paths.toWorkingAppleSiliconVM(named: name))
    }

    func unpackVM(name: String) async throws {
        try Compressor.decompress(
            archiveAt: Paths.toArchivedVM(named: name),
            to: Paths.toAppleSiliconVM(named: name)
        )
    }

    func packageVM(name: String) async throws {
        try Compressor.compress(
            directory: Paths.toAppleSiliconVM(named: name),
            to: Paths.toArchivedVM(named: name)
        )
    }

    func resetVMWorkingDirectory() throws {
        try FileManager.default.removeItemIfExists(at: Paths.vmWorkingStorageDirectory)
        try FileManager.default.createDirectory(at: Paths.vmWorkingStorageDirectory, withIntermediateDirectories: true)
    }

    func cloneVM(from source: String, to destination: String) async throws {
        try FileManager.default.copyItem(
            at: try Paths.resolveVM(withNameOrHandle: source),
            to: Paths.toAppleSiliconVM(named: destination)
        )

        try VMBundle.renamingClonedBundle(at: Paths.toAppleSiliconVM(named: destination), to: destination)
    }

    func cloneVM(for launchConfiguration: LaunchConfiguration) async throws {

        if try FileManager.default.directoryExists(at: launchConfiguration.destinationPath) {
            throw HostmgrError.workingVMAlreadyExists(launchConfiguration.handle)
        }

        try FileManager.default.copyItem(
            at: try launchConfiguration.vmSourcePath,
            to: launchConfiguration.destinationPath
        )

        try VMBundle.renamingClonedBundle(at: launchConfiguration.destinationPath, to: launchConfiguration.handle)
    }

    func waitForVMStartup(name: String) async throws {
        Task.retrying(times: 5) {
            let address = try await ipAddress(forVmWithName: name)
            try await waitForSSHServer(forAddress: address)
        }
    }

    func ipAddress(forVmWithName name: String) async throws -> IPv4Address {
        let vmBundlePath = try Paths.resolveVM(withNameOrHandle: name)
        let vmBundle = try VMBundle.fromExistingBundle(at: vmBundlePath)

        return try await Task.retrying(times: 5) {
            return try DHCPLease.mostRecentLease(forMACaddress: vmBundle.macAddress).ipAddress
        }.value
    }

    func getVMImages(unusedSince cutoff: Date) async throws -> [VMUsageAggregate] {
        try await getVMUsageStats()
            .grouped()
            .unused(since: cutoff)
    }

    func getVMUsageStats() async throws -> [VMUsageRecord] {
        try await vmUsageTracker.usageStats()
    }

    func vmTemplateName(forVmWithName name: String) async throws -> String? {
        let vmBundlePath = try Paths.resolveVM(withNameOrHandle: name)
        let vmBundle = try VMBundle.fromExistingBundle(at: vmBundlePath)

        return vmBundle.templateName
    }

    func waitForSSHServer(forAddress address: IPv4Address, timeout: TimeInterval = 30) async throws {
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

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
            }

            connection.start(queue: .main)
        }
    }
}
