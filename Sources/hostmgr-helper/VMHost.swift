import Foundation
import Virtualization
import libhostmgr
import OSLog
import Network

@MainActor
class VMHost: NSObject, ObservableObject {
    static let shared = VMHost()

    private override init() {}

    @Published
    var primaryVMSlot = VirtualMachineSlot()

    @Published
    var secondaryVMSlot = VirtualMachineSlot()
}

extension VMHost: HostmgrServerDelegate {
    func start(launchConfiguration: libhostmgr.LaunchConfiguration) async throws {
        Logger.helper.log("Launching VM: \(launchConfiguration.name, privacy: .public)")

        if self.primaryVMSlot.isAvailable {
            Logger.helper.log("Using Primary Slot")
            try await primaryVMSlot.start(launchConfiguration: launchConfiguration)
            return
        }

        if self.secondaryVMSlot.isAvailable {
            Logger.helper.log("Using Secondary Slot")
            try await secondaryVMSlot.start(launchConfiguration: launchConfiguration)
            return
        }

        throw HostmgrError.noVMSlotsAvailable
    }
    
    func stop(handle: String) async throws {
        Logger.helper.log("Received stop request for \(handle, privacy: .public)")

        if self.primaryVMSlot.isRunningVM(withHandle: handle) {
            try await primaryVMSlot.stopVirtualMachine()
        }

        if self.secondaryVMSlot.isRunningVM(withHandle: handle) {
            try await secondaryVMSlot.stopVirtualMachine()
        }
    }
    
    func stopAll() async throws {
        var count = 0

        repeat {
            do {
                try await self.primaryVMSlot.stopVirtualMachine()
                try await self.secondaryVMSlot.stopVirtualMachine()
                return
            } catch {
                try await Task.sleep(for: .seconds(1))
                count += 1
            }

        } while(count < 10)
    }
}
