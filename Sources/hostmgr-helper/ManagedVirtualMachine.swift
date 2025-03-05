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

    func start() -> Task<Void, Error> {
        Task {
            do {
                Logger.helper.log("Start task started for \(handle).")
                let newMachine = try await config.setupVirtualMachine()
                self.machine = newMachine
                try await newMachine.start()

                if config.waitForNetworking {
                    self.ip = try await vmManager.ipAddress(forVmWithName: handle)
                    Logger.helper.log(
                        "Startup of \(handle) complete – IP Address: \(ip.debugDescription)"
                    )
                } else {
                    self.ip = .any
                    Logger.helper.log(
                        "Startup of \(handle) in progress – skipped waiting for IP address per launch configuration"
                    )
                }
            } catch {
                Logger.helper.error("Startup of \(handle) failed: \(error)")
                await cleanUp()
                throw error
            }
        }
    }

    func stop() async {
        Logger.helper.log("Stop called for \(handle).")
        if let machine {
            /// Don't send events to delegate anymore
            machine.delegate = nil
            if machine.canStop {
                do {
                    Logger.helper.debug("Attempting to stop VM \(handle).")
                    /// Note: It's suspected that this call may hang under certain conditions.
                    try await machine.stop()
                } catch {
                    Logger.helper.error("Failed to stop VM \(handle): \(error)")
                }
            }
        }
        await cleanUp()
    }

    private func cleanUp() async {
        Logger.helper.log("Attempting cleanup of \(handle)")
        machine = nil
        do {
            try await vmManager.removeVM(name: handle)
        } catch {
            Logger.helper.error("Failed to remove VM file for \(handle): \(error)")
        }
    }
}
