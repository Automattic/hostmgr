import Foundation
import Virtualization
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
        case starting(LaunchConfiguration, Task<ManagedVirtualMachine, Error>)
        case running(ManagedVirtualMachine, IPv4Address)
        case stopping(LaunchConfiguration)
        case crashed(Error)
    }

    enum Errors: Error {
        /// the slot was asked to start a new VM when it wasn't available
        case invalidStartState
        /// the VM was stopped while starting
        case vmStartCancelled
    }

    struct ManagedVirtualMachine {
        let machine: VZVirtualMachine
        let config: LaunchConfiguration
        let ip: IPv4Address

        var handle: String {
            config.handle
        }
    }

    private let vmManager = VMManager()

    @Published
    var status: Status = .empty

    let role: Role

    init(role: Role) {
        self.role = role
    }

    func start(launchConfiguration: LaunchConfiguration) async throws {
        guard isAvailable else {
            throw Errors.invalidStartState
        }

        do {
            let startTask = Task {
                try await createManagedVm(launchConfiguration: launchConfiguration)
            }

            self.status = .starting(launchConfiguration, startTask)
            let newVM = try await startTask.value
            if startTask.isCancelled {
                Logger.helper.debug("Start task was cancelled for \(newVM.handle)")
                throw Errors.vmStartCancelled
            }

            newVM.machine.delegate = self
            Logger.helper.log("Setting \(role.displayName) slot to running \(newVM.handle).")
            self.status = .running(newVM, newVM.ip)
        } catch {
            Logger.helper.error("Error launching VM: \(error.localizedDescription)")
            try? await stop(withError: error)
            throw error
        }
    }

    private func createManagedVm(launchConfiguration: LaunchConfiguration) async throws -> ManagedVirtualMachine {
        Logger.helper.log("Creating VM \(launchConfiguration.handle).")
        let virtualMachine = try await launchConfiguration.setupVirtualMachine()
        try await virtualMachine.start()

        let ipAddress: IPv4Address
        if launchConfiguration.waitForNetworking {
            ipAddress = try await vmManager.ipAddress(forVmWithName: launchConfiguration.handle)
            Logger.helper.log("Startup complete – IP Address: \(ipAddress.debugDescription)")
        } else {
            Logger.helper.log("Startup in progress – skipped waiting for IP address per launch configuration")
            ipAddress = .any
        }
        return ManagedVirtualMachine(machine: virtualMachine, config: launchConfiguration, ip: ipAddress)
    }

    private func stopManagedVm(_ mvm: ManagedVirtualMachine) async {
        Logger.helper.log("Stopping VM \(mvm.handle).")
        /// Quit responding to delegate methods
        mvm.machine.delegate = nil
        do {
            if mvm.machine.canStop {
                try await mvm.machine.stop()
            }
        } catch {
            Logger.helper.error("Failure when stopping VM: \(error)")
        }
    }

    private func cleanManagedVM(_ handle: String) async {
        Logger.helper.log("Cleaning up VM \(handle).")
        do {
            try await vmManager.removeVM(name: handle)
        } catch {
            Logger.helper.error("Failure when removing VM files: \(error)")
        }
    }

    func stop(withError error: Error? = nil) async throws {
        Logger.helper.log("Stopping \(role.displayName) slot.")
        switch status {
        case .starting(let config, let task):
            self.status = .stopping(config)
            task.cancel()
            await cleanManagedVM(config.handle)
        case .running(let mvm, _):
            self.status = .stopping(mvm.config)
            await stopManagedVm(mvm)
            await cleanManagedVM(mvm.handle)
        default:
            /// For all other states we do nothing.
            Logger.helper.debug("Stop called while state was \(status) - doing nothing.")
            return
        }

        if let error {
            Logger.helper.error("Resetting slot with crashed state: \(error)")
            self.status = .crashed(error)
        } else {
            Logger.helper.log("Resetting slot to empty state.")
            self.status = .empty
        }
    }

    func isConfiguredForHandle(_ handle: String) -> Bool {
        switch status {
        case .starting(let config, _), .stopping(let config):
            Logger.helper.debug(
                "Comparing \(config.handle) and \(handle)"
            )
            return config.handle == handle
        case .running(let mvm, _):
            Logger.helper.debug(
                "Comparing \(mvm.config.handle) and \(handle)"
            )
            return mvm.config.handle == handle
        case .empty, .crashed:
            Logger.helper.debug(
                "\(self.role) slot had no handle configured."
            )
            return false
        }
    }

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
            try await stop()
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Logger.helper.error("Virtual Machine Crashed: \(error.localizedDescription)")
        Task {
            try await stop(withError: error)
        }
    }

    nonisolated func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        Logger.helper.error("Network attachment was disconnected: \(error.localizedDescription)")
        Task {
            try await stop()
        }
    }
}
