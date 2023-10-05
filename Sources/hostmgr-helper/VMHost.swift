import Foundation
import Virtualization
import libhostmgr
import OSLog
import Network

class VMHost: NSObject, ObservableObject {

    class VirtualMachineSlot: NSObject, ObservableObject {

        @Published @MainActor
        var ipAddress: IPv4Address?

        @Published
        var error: Error?

        @Published
        var vm: VZVirtualMachine?

        var launchConfiguration: LaunchConfiguration? {
            didSet {
                self.name = launchConfiguration?.name
                self.handle = launchConfiguration?.handle
            }
        }

        @Published
        var name: String?

        @Published
        var handle: String?
    }

    @Published
    var primaryVM = VirtualMachineSlot()

    @Published
    var secondaryVM = VirtualMachineSlot()

    @Published
    var hasRunningVMs: Bool = false

    @DIInjected
    private var vmManager: any VMManager

    private var refreshTask: Task<Void, Error>?

    override init() {
        super.init()

        self.refreshTask = Task(priority: .background) {
            repeat {
                do {
                    if let primaryHandle = primaryVM.handle, await primaryVM.ipAddress == nil{
                        Logger.helper.log("Looking up IP for: \(primaryHandle, privacy: .public)")
                        let ipAddress = try await vmManager.ipAddress(forVmWithName: primaryHandle)
                        Logger.helper.log("IP for: \(primaryHandle, privacy: .public) is \(ipAddress.debugDescription, privacy: .public)")

                        await MainActor.run {
                            primaryVM.ipAddress = ipAddress
                            Logger.helper.warning("Set IP for PrimaryVM")
                        }
                    }

                    if let secondaryHandle = secondaryVM.handle, await secondaryVM.ipAddress == nil {
                        Logger.helper.log("Looking up IP for: \(secondaryHandle, privacy: .public)")
                        let ipAddress = try await vmManager.ipAddress(forVmWithName: secondaryHandle)
                        Logger.helper.log("IP for: \(secondaryHandle, privacy: .public) is \(ipAddress.debugDescription, privacy: .public)")

                        await MainActor.run {
                            secondaryVM.ipAddress = ipAddress
                            Logger.helper.warning("Set IP for SecondaryVM")
                        }
                    }

                    try await Task.sleep(for: .seconds(1))
                }
                catch {
                    Logger.helper.error("Error Fetching VM IP Address: \(error.localizedDescription, privacy: .public)")
                }
            } while(!Task.isCancelled)
        }
    }

    @MainActor
    func startVM(launchConfiguration: LaunchConfiguration) async throws {
        Logger.helper.log("Launching VM: \(launchConfiguration.name, privacy: .public)")

        let virtualMachine = try await launchConfiguration.setupVirtualMachine()
        virtualMachine.delegate = self

        if self.primaryVM.vm == nil {
            self.primaryVM.vm = virtualMachine
            self.primaryVM.launchConfiguration = launchConfiguration
            self.updateUI()
            try await self.primaryVM.vm?.start()
        } else if self.secondaryVM.vm == nil {
            self.secondaryVM.vm = virtualMachine
            self.secondaryVM.launchConfiguration = launchConfiguration
            self.updateUI()
            try await self.secondaryVM.vm?.start()
        }
    }

    @MainActor
    func stopVM(handle: String) async throws {
        if primaryVM.handle == handle {
            try await primaryVM.vm?.stop()
            self.primaryVM.vm = nil
            self.primaryVM.launchConfiguration = nil
        }

        if secondaryVM.handle == handle {
            try await secondaryVM.vm?.stop()
            self.secondaryVM.vm = nil
            self.secondaryVM.launchConfiguration = nil
        }

        self.updateUI()
    }

    @MainActor
    func stopAllVMs() async throws {
        try await primaryVM.vm?.stop()
        try await secondaryVM.vm?.stop()

        self.updateUI()
    }

    @MainActor
    func updateUI(){
        self.hasRunningVMs = !(self.primaryVM.vm == nil && self.secondaryVM.vm == nil)
    }
}

extension VMHost: VZVirtualMachineDelegate {

    /// Called when a VM is stopped gracefully
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Task {
            if primaryVM.vm == virtualMachine, let handle = primaryVM.handle {
                try await stopVM(handle: handle)
            }

            if secondaryVM.vm == virtualMachine, let handle = secondaryVM.handle {
                try await stopVM(handle: handle)
            }
        }
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        if primaryVM.vm == virtualMachine {
            primaryVM.error = error
        }

        if secondaryVM.vm == virtualMachine {
            secondaryVM.error = error
        }
    }
}
