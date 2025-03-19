import Foundation
import Virtualization
import SwiftUI
import OSLog
import Network
import libhostmgr

@MainActor
class VirtualMachineSlot: NSObject, ObservableObject {
    @Published
    var state: State = .empty

    let role: Role

    init(role: Role) {
        self.role = role
    }

    /// Requests that the slot go to a running state with a `ManagedVirtualMachine`
    ///
    /// This method throws an error if trying to start in an invalid state, or if there was an error
    /// starting the VM.
    /// - Parameter managedVirtualMachine: A type that conforms to `ManagedVirtualMachine`.
    func start(managedVirtualMachine: ManagedVirtualMachine) async throws {
        Logger.helper.log("Launch request for \(managedVirtualMachine.config.handle).")

        guard isAvailable else {
            throw Errors.invalidStartState
        }

        do {
            let startTask = Task { try await managedVirtualMachine.start() }
            try state.transitionTo(.starting(managedVirtualMachine, startTask))
            try await startTask.value

            Logger.helper.log("Setting \(role.displayName) slot to running \(managedVirtualMachine.config.handle).")
            managedVirtualMachine.setDelegate(self)
            try state.transitionTo(.running(managedVirtualMachine))
        } catch is CancellationError {
            // We're already transitioning from Starting -> Stopping by an external call, so
            // we just throw.
            Logger.helper.debug("Start task was cancelled for \(managedVirtualMachine.config.handle).")
            throw Errors.vmStartCancelled
        } catch {
            // We only call stop to reset the slot state - VM stopping and cleanup already occurred
            // in the ManagedVirtualMachine.
            Logger.helper.error("Error launching VM: \(error.localizedDescription)")
            try? await stop(withError: error)
            throw error
        }
    }

    /// Puts the slot into a stopped state if it's a valid request.
    ///
    /// - This method throws an error if trying to stop in a state other than `.starting` and `.running`.
    /// - Parameters:
    ///   - error: Error to include if the slot is stopping because of an error.
    ///   - clean: If VM files should also be cleaned.
    func stop(withError error: Error? = nil, clean: Bool = false) async throws {
        Logger.helper.log(
            "Stopping \(clean ? "and cleaning " : "")\(role.displayName) slot with current status \(state)."
        )
        switch state {
        case .starting(let config, let task):
            try state.transitionTo(.stopping(config))
            task.cancel()
        case .running(let mvm):
            try state.transitionTo(.stopping(mvm))
            await mvm.stop()
            if clean { mvm.clean() }
        case.stopping:
            Logger.helper.error("Error: Stop was called while stopping.")
            throw Errors.invalidStopState
        case .empty, .crashed:
            Logger.helper.info("Stop called while state was \(state).")
            return
        }

        if let error {
            Logger.helper.error("Resetting slot with crashed state: \(error)")
            try state.transitionTo(.crashed(error))
        } else {
            Logger.helper.log("Resetting slot to empty state.")
            try state.transitionTo(.empty)
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

    /// If the slot is available.
    var isAvailable: Bool {
        switch state {
        case .empty, .crashed: return true
        default: return false
        }
    }
}

// MARK: - Types
extension VirtualMachineSlot {
    enum Role: String, Codable {
        case primary
        case secondary

        var displayName: String {
            self.rawValue.localizedCapitalized
        }
    }

    @MainActor
    enum State: Equatable {
        case empty
        case starting(ManagedVirtualMachine, Task<Void, Error>)
        case running(ManagedVirtualMachine)
        case stopping(ManagedVirtualMachine)
        case crashed(Error)

        nonisolated static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty):
                return true
            case (.starting, .starting):
                return true
            case (.running, .running):
                return true
            case (.stopping, .stopping):
                return true
            case (.crashed, .crashed):
                return true
            default:
                return false
            }
        }

        var handle: String? {
            switch self {
            case .starting(let mvm, _), .running(let mvm), .stopping(let mvm):
                return mvm.config.handle
            case .empty, .crashed:
                return nil
            }
        }

        mutating func transitionTo(_ newState: State) throws {
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
                throw Errors.invalidStateTransition
            }

            Logger.helper.info("Slot state transitioned from \(self) to \(newState)")
            self = newState
        }
    }

    enum Errors: Error {
        /// The slot was asked to start a new VM when it wasn't available.
        case invalidStartState
        /// The slot was asked to stop a VM when it was already stopping
        case invalidStopState
        /// The slot tried to transition to an invalid state.
        case invalidStateTransition
        /// The VM was stopped while starting.
        case vmStartCancelled
    }
}

// MARK: - VZVirtualMachineDelegate conformance
extension VirtualMachineSlot: VZVirtualMachineDelegate {
    /// Called when a VM is stopped gracefully.
    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Logger.helper.log("Virtual Machine Stopped")
        Task { @MainActor in
            try await stop(clean: true)
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Logger.helper.error("Virtual Machine Crashed: \(error.localizedDescription)")
        Task { @MainActor in
            try await stop(withError: error, clean: true)
        }
    }

    nonisolated func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        Logger.helper.error("Network attachment was disconnected: \(error.localizedDescription)")
        Task { @MainActor in
            try await stop(clean: true)
        }
    }
}
