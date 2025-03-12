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

        mutating func transitionTo(newState: State) {
            switch (self, newState) {
            case (.empty, .starting):
                // Starting a new VM from a clean state.
                break
            case (.crashed, .starting):
                // Starting a new VM from a previously crashed state.
                break
            case (.starting, .running):
                // A VM is now running.
                break
            case (.starting, .stopping):
                // A VM's start failed or was cancelled.
                break
            case (.running, .stopping):
                // A VM that was successfully running is stopping.
                break
            case (.stopping, .empty):
                // The VM cleanly stopped.
                break
            case (.stopping, .crashed):
                // The VM stopped due to an error.
                break
            default:
                // Invalid transition.
                Logger.helper.error("An invalid state change was called from \(self) to \(newState).")
                return
            }

            Logger.helper.info("Slot state transitioned from \(self) to \(newState).")
            self = newState
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

    /// Requests that the slot go to a running state with a VM configured by `launchConfiguration`.
    ///
    /// This method throws an error if trying to start in an invalid state, or if there was an error
    /// initializing the VM.
    /// - Parameter launchConfiguration: VM configuration.
    func start(launchConfiguration: LaunchConfiguration) async throws {
        Logger.helper.log("Launch request for \(launchConfiguration.handle).")

        guard isAvailable else {
            throw Errors.invalidStartState
        }

        do {
            // MARK: Empty / Crashed -> Starting
            let startTask = Task { try await createManagedVm(launchConfiguration: launchConfiguration) }
            self.state.transitionTo(newState: .starting(launchConfiguration, startTask))
            let newVM = try await startTask.value
            // stop() was called while the VM was starting.
            if startTask.isCancelled { throw Errors.vmStartCancelled }

            // MARK: Starting -> Running
            Logger.helper.log("Setting \(role.displayName) slot to running \(newVM.handle).")
            newVM.machine.delegate = self

            self.state.transitionTo(newState: .running(newVM))
        } catch Errors.vmStartCancelled {
            // We're already transitioning from Starting -> Stopping by an external call.
            Logger.helper.debug("Start task was cancelled for \(launchConfiguration.handle).")

            throw Errors.vmStartCancelled
        } catch {
            // MARK: Starting -> Stopping
            Logger.helper.error("Error launching VM: \(error.localizedDescription)")
            // We only call stop to reset the slot state - VM stopping and cleanup already occurred.
            try? await stop(withError: error)
            throw error
        }
    }

    /// Puts the slot into a stopped state if it's a valid request.
    ///
    /// - This method does not clean up stopped VMs.
    /// - This method throws an error if trying to stop in a state other than `.starting` and `.running`.
    /// - Parameters:
    ///   - error: Error to include if the slot is stopping because of an error.
    func stop(withError error: Error? = nil) async throws {
        Logger.helper.log("Stopping \(role.displayName) slot with current status \(state).")
        switch state {
        case .starting(let config, let task):
            // MARK: Starting -> Stopping
            self.state.transitionTo(newState: .stopping(config))
            task.cancel()
        case .running(let mvm):
            // MARK: Running -> Stopping
            self.state.transitionTo(newState: .stopping(mvm.config))
            await stopVm(mvm.machine, handle: mvm.handle)
        default:
            Logger.helper.error("Stop called while state was \(state).")
            throw Errors.invalidStopState
        }

        if let error {
            // MARK: Stopping -> Crashed
            Logger.helper.error("Resetting slot with crashed state: \(error)")
            self.state.transitionTo(newState: .crashed(error))
        } else {
            // MARK: Stopping -> Empty
            Logger.helper.log("Resetting slot to empty state.")
            self.state.transitionTo(newState: .empty)
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

    /// Creates a running VM inside a `ManagedVirtualMachine` configured by a `LaunchConfiguration`.
    ///
    /// If any errors occur after the VM was started, this method will attempt to stop the VM and perform a cleanup.
    /// - Parameter launchConfiguration: VM configuration.
    /// - Returns: A `ManagedVirtualMachine` containing a running VM.
    private func createManagedVm(launchConfiguration: LaunchConfiguration) async throws -> ManagedVirtualMachine {
        Logger.helper.log("Creating VM \(launchConfiguration.handle).")
        // Maintain a reference to the new VM for clean up purposes.
        var newVM: VZVirtualMachine?

        do {
            let virtualMachine = try await launchConfiguration.setupVirtualMachine()
            newVM = virtualMachine
            try await virtualMachine.start()

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
            if let newVM {
                await stopVm(newVM, handle: launchConfiguration.handle)
            }
            // Note: This cleans ALL types of VMs that failed to start - even persistent
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
}

// MARK: VZVirtualMachineDelegate conformance
extension VirtualMachineSlot: VZVirtualMachineDelegate {
    /// Used internally by the class when it needs to stop the VM and run the clean up step afterwards. This may
    /// be called because of an "external" event via the `VZVirtualMachineDelegate` calls.
    ///
    /// VMs typically stop via the `hostmgr stop` command which handles cleanup on its own.
    /// Only ephemeral VM files are removed.
    /// - Parameters:
    ///   - error: Error to include if the slot is stopping because of an error.
    private func stopAndClean(withError error: Error? = nil) async throws {
        Logger.helper.log("Stopping and cleaning \(role.displayName).")
        try await stop(withError: error)
        guard let handle = state.handle else {
            return
        }

        Logger.helper.log("Cleaning up VM \(handle).")
        do {
            // Remove working (ephemeral) VMs only.
            try vmManager.removeWorkingVM(handle: handle)
            Logger.helper.log("Cleaned up VM \(handle).")
        } catch {
            Logger.helper.error("Failure when removing VM files: \(error)")
        }
    }

    /// Called when a VM is stopped gracefully.
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
