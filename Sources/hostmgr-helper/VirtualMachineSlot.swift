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

    enum State: Sendable {
        case empty
        case starting(LaunchConfiguration, Task<ManagedVirtualMachine, Error>)
        case running(ManagedVirtualMachine)
        case stopping(LaunchConfiguration)
        case crashed(Error)

        var handle: String? {
            switch self {
            case .starting(let config, _), .stopping(let config):
                return config.handle
            case .running(let mvm):
                return mvm.handle
            case .empty, .crashed:
                return nil
            }
        }
    }

    enum Errors: Error {
        /// The slot was asked to start a new VM when it wasn't available.
        case invalidStartState
        /// The slot was asked to stop a VM when it was already stopping
        case invalidStopState
        /// The VM was stopped while starting.
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
    var state: State = .empty

    let role: Role

    init(role: Role) {
        self.role = role
    }

    func start(launchConfiguration: LaunchConfiguration) async throws {
        Logger.helper.log("Launch request for \(launchConfiguration.handle).")

        guard isAvailable else {
            throw Errors.invalidStartState
        }

        do {
            // MARK: Empty / Crashed -> Starting
            let startTask = Task { try await createManagedVm(launchConfiguration: launchConfiguration) }
            self.state = .starting(launchConfiguration, startTask)
            let newVM = try await startTask.value
            // stop() was called while the VM was starting.
            if startTask.isCancelled { throw Errors.vmStartCancelled }

            // MARK: Starting -> Running
            Logger.helper.log("Setting \(role.displayName) slot to running \(newVM.handle).")
            newVM.machine.delegate = self

            self.state = .running(newVM)
        } catch Errors.vmStartCancelled {
            // We're already transitioning from Starting -> Stopping by an external call.
            Logger.helper.debug("Start task was cancelled for \(launchConfiguration.handle).")

            throw Errors.vmStartCancelled
        } catch {
            // MARK: Starting -> Stopping
            Logger.helper.error("Error launching VM: \(error.localizedDescription)")
            try? await stopAndClean(withError: error)
            throw error
        }
    }

    /// Stops a VM running in the slot. Does not clean a stopped VM.
    ///
    /// This method throws an error if trying to stop in a state other than `.starting` and `.running`.
    /// - Parameters:
    ///   - error: Error to include if the slot is stopping because of an error.
    func stop(withError error: Error? = nil) async throws {
        Logger.helper.log("Stopping \(role.displayName) slot with current status \(state).")
        switch state {
        case .starting(let config, let task):
            // MARK: Starting -> Stopping
            self.state = .stopping(config)
            task.cancel()
        case .running(let mvm):
            // MARK: Running -> Stopping
            self.state = .stopping(mvm.config)
            await stopVm(mvm.machine, handle: mvm.handle)
        default:
            Logger.helper.error("Stop called while state was \(state).")
            throw Errors.invalidStopState
        }

        if let error {
            // MARK: Stopping -> Crashed
            Logger.helper.error("Resetting slot with crashed state: \(error)")
            self.state = .crashed(error)
        } else {
            // MARK: Stopping -> Empty
            Logger.helper.log("Resetting slot to empty state.")
            self.state = .empty
        }
    }

    func isConfiguredForHandle(_ handle: String) -> Bool {
        guard let slotHandle = state.handle else {
            Logger.helper.debug(
                "\(role.displayName) slot had no handle configured."
            )
            return false
        }

        Logger.helper.debug(
            "Comparing \(slotHandle) and \(handle)."
        )
        return slotHandle == handle
    }

    var isAvailable: Bool {
        Logger.helper.debug(
            "Slot availability check: \(role.displayName) slot has \(state) status."
        )

        switch self.state {
        case .empty, .crashed: return true
        default: return false
        }
    }

    private func createManagedVm(launchConfiguration: LaunchConfiguration) async throws -> ManagedVirtualMachine {
        Logger.helper.log("Creating VM \(launchConfiguration.handle).")
        let virtualMachine = try await launchConfiguration.setupVirtualMachine()
        try await virtualMachine.start()

        do {
            let ipAddress: IPv4Address
            if launchConfiguration.waitForNetworking {
                ipAddress = try await vmManager.ipAddress(forVmWithName: launchConfiguration.handle)
                Logger.helper.log("Startup complete – IP Address: \(ipAddress.debugDescription).")
            } else {
                Logger.helper.log("Startup in progress – skipped waiting for IP address per launch configuration.")
                ipAddress = .any
            }
            return ManagedVirtualMachine(machine: virtualMachine, config: launchConfiguration, ip: ipAddress)
        } catch {
            // Guarantee that the VM is stopped and cleaned before throwing.
            Logger.helper.error("Stopping VM \(launchConfiguration.handle) that was being launched: \(error)")
            await stopVm(virtualMachine, handle: launchConfiguration.handle)
            try? vmManager.removeVM(name: launchConfiguration.handle)
            throw error
        }
    }

    private func stopVm(_ vm: VZVirtualMachine, handle: String) async {
        Logger.helper.log("Stopping VM \(handle).")
        // Quit responding to delegate methods.
        vm.delegate = nil

        if vm.canStop {
            Logger.helper.debug("VM \(handle) claims it can be stopped.")
            do {
                try await vm.stop()
                Logger.helper.log("Stopped VM \(handle).")
            } catch {
                Logger.helper.error("Failure when stopping VM: \(error)")
            }
        }
    }

    /// Used internally by the class when it needs to stop the VM and run the clean up step afterwards. This may
    /// be called because of an "external" event: A VM gracefully stopped via macOS, crashed, or failed to initialize.
    ///
    /// VMs typically stop via the `hostmgr stop` command which handles cleanup on its own.
    /// Only ephemeral VM files are removed.
    /// - Parameters:
    ///   - error: Error to include if the slot is stopping because of an error.
    ///   - cleanAllTypes: If `true` the VM will be deleted even if a persistent or template type.
    private func stopAndClean(withError error: Error? = nil) async throws {
        Logger.helper.log("Stopping and cleaning \(role.displayName).")
        try await stop(withError: error)
        guard let handle = state.handle else {
            return
        }

        Logger.helper.log("Cleaning up VM \(handle).")
        do {
            // Remove working (ephemeral) VMs only
            try vmManager.removeWorkingVM(handle: handle)
            Logger.helper.log("Cleaned up VM \(handle).")
        } catch {
            Logger.helper.error("Failure when removing VM files: \(error)")
        }
    }
}

// MARK: VZVirtualMachineDelegate conformance
extension VirtualMachineSlot: VZVirtualMachineDelegate {
    /// Called when a VM is stopped gracefully
    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Logger.helper.log("Virtual Machine Stopped")
        Task {
            try await stopAndClean()
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Logger.helper.error("Virtual Machine Crashed: \(error.localizedDescription)")
        Task {
            try await stopAndClean(withError: error)
        }
    }

    nonisolated func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        Logger.helper.error("Network attachment was disconnected: \(error.localizedDescription)")
        Task {
            try await stopAndClean()
        }
    }
}
