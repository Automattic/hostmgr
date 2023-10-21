import Foundation
@preconcurrency import Virtualization
import SwiftUI
import OSLog
import Network
import libhostmgr

@MainActor
class VirtualMachineSlot: NSObject, ObservableObject, VZVirtualMachineDelegate {

    enum Status: Sendable {
        case empty
        case starting(LaunchConfiguration)
        case running(LaunchConfiguration, IPv4Address)
        case stopping
        case crashed(Error)
    }

    private let vmManager = VMManager()

    private var virtualMachine: VZVirtualMachine?

    @Published @MainActor
    var status: Status = .empty

    @MainActor
    func start(launchConfiguration: LaunchConfiguration) async throws {

        self.status = .starting(launchConfiguration)

        do {
            let virtualMachine = try await launchConfiguration.setupVirtualMachine()
            virtualMachine.delegate = self

            self.virtualMachine = virtualMachine
            try await virtualMachine.start()

            let ipAddress = try await vmManager.ipAddress(forVmWithName: launchConfiguration.handle)
            Logger.helper.log("Startup complete – IP Address: \(ipAddress.debugDescription, privacy: .public)")

            self.status = .running(launchConfiguration, ipAddress)
        } catch {
            Logger.helper.error("Error launching VM: \(error.localizedDescription, privacy: .public)")
            Logger.helper.error("Attempting Cleanup of \(launchConfiguration.handle, privacy: .public)")
            try await vmManager.removeVM(name: launchConfiguration.handle)

            self.status = .crashed(error)
            throw error
        }
    }

    @MainActor
    func stopVirtualMachine() async throws {
        self.status = .stopping
        try await virtualMachine?.stop()
        self.status = .empty
    }

    /// Handle a VM that was stopped from outside this object (for instance – by being shut down internally)
    ///
    /// No need to do anything except some internal bookkeeping
    ///
    @MainActor
    func flush() async throws {
        self.virtualMachine = nil
        self.status = .empty
    }

    @MainActor
    func isRunningVM(withHandle handle: String) -> Bool {
        switch self.status {
        case .empty:
            return false
        case .starting(let launchConfiguration):
            return launchConfiguration.handle == handle
        case .running(let launchConfiguration, _):
            Logger.helper.trace(
                "Comparing \(launchConfiguration.handle, privacy: .public) and \(handle, privacy: .public)"
            )
            return launchConfiguration.handle == handle
        case .stopping:
            return false
        case .crashed:
            return false
        }
    }

    @MainActor
    func isRunning(virtualMachine: VZVirtualMachine) -> Bool {
        self.virtualMachine == virtualMachine
    }

    @MainActor
    var isAvailable: Bool {
        switch self.status {
        case .empty, .crashed: return true
        default: return false
        }
    }

//    /// Called when a VM is stopped gracefully
//    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
//        Logger.helper.log("Virtual Machine Stopped")
//
//        assert(Thread.isMainThread)
//
////        self.status = .empty
////        self.virtualMachine = nil
//    }
//
//    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
//        assert(Thread.isMainThread)
////        self.status = .crashed(error)
//    }
//
//    func virtualMachine(
//        _ virtualMachine: VZVirtualMachine,
//        networkDevice: VZNetworkDevice,
//        attachmentWasDisconnectedWithError error: Error
//    ) {
//        debugPrint("Network attachment was disconnected")
//        Logger.helper.log("Network attachment was disconnected: \(error.localizedDescription)")
//    }
}
