import Foundation
@preconcurrency import Virtualization
import SwiftUI
import OSLog
import Network
import libhostmgr

@MainActor
class VirtualMachineSlot: NSObject, ObservableObject {

    enum Role: String, Codable {
        case primary
        case secondary

        var displayName: String {
            self.rawValue.localizedCapitalized
        }
    }

    enum Status: Sendable {
        case empty
        case starting(LaunchConfiguration)
        case running(LaunchConfiguration, IPv4Address)
        case stopping
        case crashed(Error)
    }

    struct ManagedVirtualMachine {
        let machine: VZVirtualMachine
        let config: LaunchConfiguration
    }

    private let vmManager = VMManager()

    @Published
    var managedVirtualMachine: ManagedVirtualMachine?

    @Published @MainActor
    var status: Status = .empty

    @Published @MainActor
    var role: Role

    init(role: Role) {
        self.role = role
    }

    @MainActor
    func start(launchConfiguration: LaunchConfiguration) async throws {

        self.status = .starting(launchConfiguration)

        do {
            let virtualMachine = try await launchConfiguration.setupVirtualMachine()
            virtualMachine.delegate = self
            self.managedVirtualMachine = ManagedVirtualMachine(machine: virtualMachine, config: launchConfiguration)

            try await virtualMachine.start()

            if launchConfiguration.waitForNetworking {
                let ipAddress = try await vmManager.ipAddress(forVmWithName: launchConfiguration.handle)
                Logger.helper.log("Startup complete – IP Address: \(ipAddress.debugDescription)")
                self.status = .running(launchConfiguration, ipAddress)
            } else {
                Logger.helper.log("Startup in progress – skipped waiting for IP address per launch configuration")
                self.status = .running(launchConfiguration, .any)
            }
        } catch {
            Logger.helper.error("Error launching VM: \(error.localizedDescription)")
            Logger.helper.error("Attempting Cleanup of \(launchConfiguration.handle)")

            do {
                try await vmManager.removeVM(name: launchConfiguration.handle)
            } catch {
                Logger.helper.error("Failed to remove VM file: \(error)")
            }
            self.managedVirtualMachine = nil
            self.status = .crashed(error)
            throw error
        }
    }

    @MainActor
    func stopVirtualMachine() async throws {
        switch status {
        case .starting, .running:
            self.status = .stopping
        default:
            break
        }
        if let machine = managedVirtualMachine?.machine, machine.canStop {
            do {
                try await machine.stop()
            } catch {
                Logger.helper.error("Failed to stop VM: \(error)")
            }
        }
        await resetSlot()
    }

    /// Resets the slot to a stopped status
    ///
    /// No need to do anything except some internal bookkeeping
    /// - Parameter error: Error supplied if the VM crashed
    @MainActor
    func resetSlot(withError error: Error? = nil) async {
        if let managedVirtualMachine {
            do {
                try await vmManager.removeVM(name: managedVirtualMachine.config.handle)
            } catch {
                Logger.helper.error("Failed to remove VM file: \(error)")
            }
            self.managedVirtualMachine = nil
        }

        if let error {
            Logger.helper.error("Resetting slot with crashed state: \(error)")
            self.status = .crashed(error)
        } else {
            self.status = .empty
        }
    }

    @MainActor
    func isConfiguredForHandle(_ handle: String) -> Bool {
        guard let configHandle = managedVirtualMachine?.config.handle else {
            return false
        }
        Logger.helper.debug(
            "Comparing \(configHandle) and \(handle)"
        )
        return configHandle == handle
    }

    @MainActor
    var isAvailable: Bool {
        switch self.status {
        case .empty, .crashed: return true
        default: return false
        }
    }
}

// MARK: VZVirtualMachineDelegate conformance
extension VirtualMachineSlot: VZVirtualMachineDelegate {
    /// Called when a VM is stopped gracefully
    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Logger.helper.log("Virtual Machine Stopped")
        Task {
            await resetSlot()
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Logger.helper.error("Virtual Machine Crashed: \(error.localizedDescription)")
        Task {
            await resetSlot(withError: error)
        }
    }

    nonisolated func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        Logger.helper.error("Network attachment was disconnected: \(error.localizedDescription)")
        Task {
            try await stopVirtualMachine()
        }
    }
}
