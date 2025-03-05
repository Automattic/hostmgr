import Foundation
import Virtualization
import OSLog
import Network
import libhostmgr

@MainActor
class ManagedVirtualMachine {
    private let vmManager = VMManager()
    private var state: State = .stopped
    private(set) var machine: VZVirtualMachine?
    private(set) var ip: IPv4Address?

    enum Errors: Error {
        /// the machine was not in a state to start
        case vmStartFailed
    }

    enum State {
        case starting
        case running
        case stopping
        case stopped
    }

    let config: LaunchConfiguration

    var handle: String {
        config.handle
    }

    init(config: LaunchConfiguration) {
        self.config = config
    }

    /// Creates and starts the underlying virtual machine. If anything fails in the process
    /// of starting, state is reset and the VM files are cleaned.
    func start() async throws {
        Logger.helper.log("Start called for VM \(handle)")
        guard state == .stopped else {
            throw Errors.vmStartFailed
        }
        self.state = .starting

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
            self.state = .running
        } catch {
            Logger.helper.error("Startup of \(handle) failed: \(error)")
            await stop()
            throw error
        }
    }

    /// Stops a running machine and cleans up the bundle on the filesystem.
    func stop() async {
        Logger.helper.log("Stop called for VM \(handle).")
        switch state {
        case .starting, .running:
            state = .stopping
        case .stopping, .stopped:
            Logger.helper.error(
                "Stop called for VM \(handle) while already in state \(state), ignoring"
            )
            return
        }
        if let machine {
            /// Don't send events to delegate anymore
            machine.delegate = nil
            if machine.canStop {
                do {
                    Logger.helper.debug("Attempting to stop VM \(handle)")
                    /// Note: It's suspected that this call may hang under certain conditions.
                    try await machine.stop()
                } catch {
                    Logger.helper.error("Failed to stop VM \(handle): \(error)")
                }
            }
        }
        await cleanUp()
    }

    /// Destroys the VM and cleans up its files.
    private func cleanUp() async {
        Logger.helper.log("Attempting cleanup of VM \(handle)")
        machine = nil
        do {
            try await vmManager.removeVM(name: handle)
        } catch {
            Logger.helper.error("Failed to remove files for VM \(handle): \(error)")
        }
        self.state = .stopped
    }
}
