import Foundation
import Network
import Virtualization

struct AppleSiliconVMManager: VMManager {

    typealias VM = AppleSiliconVMImage

    func startVM(name: String) async throws {
        try createWorkingDirectoriesIfNeeded()

        let launchConfiguration = LaunchConfiguration(name: name, sharedPaths: [])
        try await XPCService.startVM(withLaunchConfiguration: launchConfiguration)
    }

    func stopVM(name: String) async throws {
        try await XPCService.stopVM()
    }

    func stopAllRunningVMs() async throws {
        try await XPCService.stopVM()
    }

    func removeVM(name: String) async throws {
        try FileManager.default.removeItem(at: Paths.toAppleSiliconVM(named: name))
        try FileManager.default.removeItem(at: Paths.toArchivedVM(named: name))
        try FileManager.default.removeItem(at: Paths.toVMTemplate(named: name))
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

    func resetVMWorkingDirectory() async throws {
        for path in FileManager.default.subpaths(at: Paths.vmWorkingStorageDirectory) {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    func cloneVM(from source: String, to destination: String) async throws {
        try FileManager.default.copyItem(
            at: Paths.toAppleSiliconVM(named: source),
            to: Paths.toAppleSiliconVM(named: destination)
        )
    }

    func waitForVMStartup(name: String) async throws {
        let address = try await ipAddress(forVmWithName: name)
        try await waitForSSHServer(forAddress: address)
    }

    func ipAddress(forVmWithName name: String) async throws -> IPv4Address {
        let vmBundle = try VMBundle.fromExistingBundle(at: Paths.toAppleSiliconVM(named: name))
        return try DHCPLease.mostRecentLease(forMACaddress: vmBundle.macAddress).ipAddress
    }

    func purgeUnusedImages() async throws {
        // Not yet implemented
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
