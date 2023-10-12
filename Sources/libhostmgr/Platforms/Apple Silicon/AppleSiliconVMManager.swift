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
        try await HostmgrClient.start(launchConfiguration: configuration)
    }

    func stopVM(handle: String) async throws {
        try await HostmgrClient.stop(handle: handle)
        try FileManager.default.removeItemIfExists(at: Paths.toWorkingAppleSiliconVM(named: handle))
    }

    func stopAllRunningVMs() async throws {
        try await HostmgrClient.stopAllVMs()
        try resetVMWorkingDirectory()
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
            to: Paths.toVMTemplate(named: name)
        )

        try VMTemplate(at: Paths.toVMTemplate(named: name)).validate()
    }

    func packageVM(name: String) async throws {
        try Compressor.compress(
            directory: Paths.toVMTemplate(named: name),
            to: Paths.toArchivedVM(named: name)
        )
    }

    func resetVMWorkingDirectory() throws {
        try FileManager.default.removeItemIfExists(at: Paths.vmWorkingStorageDirectory)
        try FileManager.default.createDirectory(at: Paths.vmWorkingStorageDirectory, withIntermediateDirectories: true)
    }

    func cloneVM(from source: String, to destination: String) async throws {
        let bundle = try VMResolver.resolveBundle(named: source)
        _ = try bundle.createEphemeralCopy(at: Paths.toWorkingAppleSiliconVM(named: destination))
    }

    func waitForVMStartup(name: String) async throws {
        let address = try await ipAddress(forVmWithName: name)
        try await waitForSSHServer(forAddress: address)
    }

    func ipAddress(forVmWithName name: String) async throws -> IPv4Address {
        let vmBundle: VMResolver.Result = try VMResolver.resolve(name)

        switch vmBundle {
            case .bundle(let bundle): return try await ipAddress(for: bundle.macAddress)
            case .template(let template): return try await ipAddress(for: template.macAddress)
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

    func getVMImages(unusedSince cutoff: Date) async throws -> [VMUsageAggregate] {
        try await getVMUsageStats()
            .grouped()
            .unused(since: cutoff)
    }

    func getVMUsageStats() async throws -> [VMUsageRecord] {
        try await vmUsageTracker.usageStats()
    }

    func vmTemplateName(forVmWithName name: String) async throws -> String? {
        switch try VMResolver.resolve(name) {
            case .bundle(let bundle): return try bundle.templateName
            case .template(let template): return template.basename
        }
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
