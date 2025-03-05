import Foundation
import Virtualization
import OSLog
import Network
import libhostmgr

@MainActor
class ManagedVirtualMachine {
    private let vmManager = VMManager()
    private(set) var machine: VZVirtualMachine?
    private(set) var ip: IPv4Address?

    let config: LaunchConfiguration

    var handle: String {
        config.handle
    }

    init(config: LaunchConfiguration) {
        self.config = config
    }

    func start() async throws {
        Logger.helper.log("Start called for VM \(handle).")
        do {
            let newMachine = try await config.setupVirtualMachine()
            self.machine = newMachine
            try await newMachine.start()

            if config.waitForNetworking {
                self.ip = try await vmManager.ipAddress(forVmWithName: handle)
                Logger.helper.log(
                    "Startup of VM \(handle) complete – IP Address: \(ip.debugDescription)"
                )
            } else {
                self.ip = .any
                Logger.helper.log(
                    "Startup of VM \(handle) in progress – skipped waiting for IP address per launch configuration"
                )
            }
        } catch {
            Logger.helper.error("Startup of \(handle) failed: \(error)")
            await stop()
            throw error
        }
    }

    func stop() async {
        Logger.helper.log("Stop called for VM \(handle).")
        if let machine {
            /// Don't send events to delegate anymore
            machine.delegate = nil
            if machine.canStop {
                do {
                    Logger.helper.debug("Attempting to stop VM \(handle)")
                    try await stopVMWithTimeout(machine, timeout: .seconds(15))
                } catch {
                    Logger.helper.error("Failed to stop VM \(handle): \(error)")
                }
            }
        }
        await cleanUp()
    }

    /// Adds a timeout to stopping VMs because it's suspected that VZVirtualMachines can get into a state
    /// where the call to `stop()` hangs.
    private func stopVMWithTimeout(_ vm: VZVirtualMachine, timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await vm.stop()
                Logger.helper.debug("Successfully stopped VM")
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                Logger.helper.error("Timeout reached when trying to stop VM")
            }

            /// Wait for the first task to complete
            try await group.next()
            /// Cancel the other task
            group.cancelAll()
        }
    }

    private func cleanUp() async {
        Logger.helper.log("Attempting cleanup of VM \(handle)")
        machine = nil
        do {
            try await vmManager.removeVM(name: handle)
        } catch {
            Logger.helper.error("Failed to remove files for VM \(handle): \(error)")
        }
    }
}
