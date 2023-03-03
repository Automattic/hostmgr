import Foundation
import Network
import Virtualization

#if arch(arm64)
public struct VMLauncher {

    public static func prepareVirtualMachine(named name: String) throws -> VZVirtualMachine {
        let configuration = try prepareBundle(named: name).virtualMachineConfiguration()
        try configuration.validate()

        return VZVirtualMachine(configuration: configuration)
    }

    static func prepareBundle(named name: String) throws -> VMBundle {
        guard let localVM = try findLocalVM(named: name) else {
            throw CocoaError(.fileNoSuchFile)
        }

        /// We never run packaged VMs directly – instead, we make a copy, turning it back into a regular bundle
        if localVM.state == .packaged {
            return try VMTemplate(at: localVM.path).createEphemeralCopy()
        }

        /// If this isn't a VM template, just launch it directly
        return try VMBundle.fromExistingBundle(at: localVM.path)
    }

    /// Try to resolve VMs – it's possible there's more than one present with the same name.
    ///
    ///  Prioritizes VM Templates, then VMs  – ignores archives because they're not launchable
    static func findLocalVM(named name: String) throws -> LocalVMImage? {
        if let template = try LocalVMRepository().lookupTemplate(withName: name) {
            return template
        }

        if let bundle = try LocalVMRepository().lookupBundle(withName: name) {
            return bundle
        }

        return nil
    }

    public static func waitForSSHServer(forAddress address: IPv4Address, timeout: TimeInterval = 30) async throws {
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
#endif
