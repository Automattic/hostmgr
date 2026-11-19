import Foundation
import Virtualization
import libhostmgr
import OSLog
import Network
import Sentry

@MainActor
class VMHost: NSObject, ObservableObject {
    static let shared = VMHost()

    @Published
    var primaryVMSlot = VirtualMachineSlot(role: .primary)

    @Published
    var secondaryVMSlot = VirtualMachineSlot(role: .secondary)

    func vmSlot(for role: VirtualMachineSlot.Role) -> VirtualMachineSlot {
        switch role {
        case .primary: return primaryVMSlot
        case .secondary: return secondaryVMSlot
        }
    }
}

extension VMHost: HostmgrServerDelegate {
    func start(launchConfiguration: libhostmgr.LaunchConfiguration) async throws {
        Logger.helper.log("Launching VM: \(launchConfiguration.name)")

        if self.primaryVMSlot.isAvailable {
            Logger.helper.log("Using Primary Slot")
            let vm = try VZManagedVirtualMachine(launchConfiguration: launchConfiguration)
            try await primaryVMSlot.start(managedVirtualMachine: vm)
            return
        }

        if self.secondaryVMSlot.isAvailable {
            Logger.helper.log("Using Secondary Slot")
            let vm = try VZManagedVirtualMachine(launchConfiguration: launchConfiguration)
            try await secondaryVMSlot.start(managedVirtualMachine: vm)
            return
        }

        if Configuration.shared.reportNoSlotsErrorToSentry == true {
            Logger.helper.debug("Reporting no slots error to Sentry")
            SentrySDK.capture(error: HostmgrError.noVMSlotsAvailable)
        }
        throw HostmgrError.noVMSlotsAvailable
    }

    func stop(handle: String) async throws {
        Logger.helper.log("Received stop request for \(handle)")

        if self.primaryVMSlot.isConfiguredForHandle(handle) {
            try await primaryVMSlot.stop()
        }

        if self.secondaryVMSlot.isConfiguredForHandle(handle) {
            try await secondaryVMSlot.stop()
        }
    }

    /// Stops both slots, retrying each one that fails. Throws the last failure if a slot still
    /// hasn't stopped after 10 attempts, so the caller doesn't remove files from under a running VM.
    func stopAll() async throws {
        var count = 0
        var lastError: Error?

        repeat {
            lastError = nil

            // Stop each slot independently, so one that fails doesn't keep the other running.
            for slot in [self.primaryVMSlot, self.secondaryVMSlot] {
                do {
                    try await slot.stop()
                } catch {
                    lastError = error
                }
            }

            guard lastError != nil else {
                return
            }

            try await Task.sleep(for: .seconds(1))
            count += 1
        } while(count < 10)

        if let lastError {
            throw lastError
        }
    }
}
