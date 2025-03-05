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
        case starting(ManagedVirtualMachine, Task<Void, Error>)
        case running(ManagedVirtualMachine)
        case stopping(ManagedVirtualMachine)
        case crashed(Error)
    }

    enum Errors: Error {
        /// the slot was asked to start a new VM when it wasn't available
        case invalidStartState
        /// the VM was stopped while starting
        case vmStartCancelled
    }

    @Published @MainActor
    var status: Status = .empty

    @Published @MainActor
    var role: Role

    init(role: Role) {
        self.role = role
    }

    @MainActor
    func start(launchConfiguration: LaunchConfiguration) async throws {
        guard isAvailable else {
            throw Errors.invalidStartState
        }

        do {
            let mvm = ManagedVirtualMachine(config: launchConfiguration)
            let startTask = Task { try await mvm.start() }
            self.status = .starting(mvm, startTask)

            try await startTask.value
            if startTask.isCancelled {
                Logger.helper.debug("Start task was cancelled for \(mvm.handle)")
                throw Errors.vmStartCancelled
            }
            mvm.machine?.delegate = self
            self.status = .running(mvm)
        } catch {
            try? await stop(withError: error)
            throw error
        }
    }

    @MainActor
    func stop(withError error: Error? = nil) async throws {
        switch status {
        case .starting(let mvm, let task):
            status = .stopping(mvm)
            task.cancel()
            await mvm.stop()
        case .running(let mvm):
            status = .stopping(mvm)
            await mvm.stop()
        case .stopping, .empty, .crashed:
            Logger.helper.debug(
                "\(self.role.displayName) slot was asked to stop with \(status) status."
            )
            return
        }

        if let error {
            Logger.helper.error(
                "Resetting \(self.role) slot with crashed state: \(error)"
            )
            self.status = .crashed(error)
        } else {
            Logger.helper.debug(
                "Setting \(self.role) slot to empty state."
            )
            self.status = .empty
        }
    }

    @MainActor
    func isConfiguredForHandle(_ handle: String) -> Bool {
        switch status {
        case .starting(let mvm, _), .running(let mvm), .stopping(let mvm):
            Logger.helper.debug(
                "Comparing \(mvm.handle) and \(handle)"
            )
            return mvm.handle == handle
        case .empty, .crashed:
            Logger.helper.debug(
                "\(self.role) slot had no handle configured"
            )
            return false
        }
    }

    @MainActor
    var isAvailable: Bool {
        switch self.status {
        case .starting(let mvm, _), .running(let mvm), .stopping(let mvm):
            Logger.helper.debug(
                "\(role.displayName) slot is not available. \(mvm.handle) has status \(self.status)"
            )
            return false
        case .empty, .crashed:
            Logger.helper.debug(
                "\(role.displayName) slot is available."
            )
            return true
        }
    }
}

// MARK: VZVirtualMachineDelegate conformance
extension VirtualMachineSlot: VZVirtualMachineDelegate {
    /// Called when a VM is stopped gracefully
    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Logger.helper.log("Virtual machine stopped")
        Task {
            try? await stop()
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Logger.helper.error("Virtual machine crashed: \(error.localizedDescription)")
        Task {
            try? await stop(withError: error)
        }
    }

    nonisolated func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        Logger.helper.error("Network attachment was disconnected: \(error.localizedDescription)")
        Task {
            try? await stop()
        }
    }
}
