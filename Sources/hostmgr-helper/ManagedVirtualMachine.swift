import Foundation
import Virtualization
import OSLog
import Network
import libhostmgr

@MainActor
protocol ManagedVirtualMachine: Sendable {
    /// The configuration used to launch the VM.
    var config: LaunchConfiguration { get }
    /// The IP address of the VM.
    var ip: IPv4Address { get }

    /// Starts the VM. Handles clean-up if anything goes wrong.
    func start() async throws
    /// Stops the VM.
    func stop() async
    /// Cleans the VM files.
    func clean()
    /// Sets the slot to be a delegate for the VM.
    func setDelegate(_ delegate: VirtualMachineSlot)
}

@MainActor
class VZManagedVirtualMachine: ManagedVirtualMachine {
    let machine: VZVirtualMachine
    let config: LaunchConfiguration
    var ip: IPv4Address = .any

    private let vmManager = VMManager()

    var handle: String {
        config.handle
    }

    /// Creates a running VM inside a `ManagedVirtualMachine` configured by a `LaunchConfiguration`.
    ///
    /// If any errors occur this method will attempt to perform a cleanup.
    /// - Parameter launchConfiguration: VM configuration.
    init(launchConfiguration: LaunchConfiguration) throws {
        Logger.helper.log("Creating VM \(launchConfiguration.handle).")
        do {
            self.machine = try launchConfiguration.setupVirtualMachine()
            self.config = launchConfiguration
        } catch {
            // Note: This cleans ALL types of VMs that failed to start - even persistent.
            Logger.helper.info("Cleaning all VM files for \(launchConfiguration.handle).")
            try? vmManager.removeVM(name: launchConfiguration.handle)
            throw error
        }
    }

    /// Starts the VM and sets the IP if configured to wait for networking.
    ///
    /// If any errors occur after the VM was started, this method will attempt to stop the VM and perform a cleanup.
    func start() async throws {
        Logger.helper.log("Starting VM \(handle).")
        do {
            try Task.checkCancellation()
            try await machine.start()
            if config.waitForNetworking {
                try Task.checkCancellation()
                self.ip = try await vmManager.ipAddress(forVmWithName: config.handle)
                Logger.helper.log("Startup complete – IP Address: \(ip.debugDescription).")
            } else {
                Logger.helper.log("Startup in progress – skipped waiting for IP address per launch configuration.")
            }
        } catch {
            // Guarantee that the VM is stopped and cleaned before throwing.
            Logger.helper.error("Stopping VM \(config.handle) that was being launched: \(error)")
            await stop()
            // Note: This cleans ALL types of VMs that failed to start - even persistent.
            Logger.helper.info("Cleaning all VM files for \(config.handle).")
            try? vmManager.removeVM(name: handle)
            throw error
        }
    }

    func setDelegate(_ delegate: VirtualMachineSlot) {
        machine.delegate = delegate
    }

    /// Stops a VZVirtualMachine if it's in a state to be stopped.
    /// - Parameters:
    ///   - vm: VZVirtualMachine
    ///   - handle: Handle to include in logs.
    func stop() async {
        Logger.helper.log("Stopping VM \(handle).")
        // Quit responding to delegate methods.
        machine.delegate = nil

        if machine.canStop {
            Logger.helper.debug("VM \(handle) claims it can be stopped.")
            do {
                // An attempt to help with https://github.com/Automattic/hostmgr/issues/128
                machine.networkDevices.forEach { $0.attachment = nil }
                try await machine.stop()
                Logger.helper.log("Stopped VM \(handle).")
            } catch {
                Logger.helper.error("Failure when stopping VM: \(error)")
            }
        }
    }

    /// Used internally by the class to clean ephemeral VMs. This may be called because of an
    /// "external" event via the `VZVirtualMachineDelegate` calls, or stopping from the menu bar.
    /// 
    /// VMs typically stop via the `hostmgr stop` command which handles cleanup on its own.
    /// Only ephemeral VM files are removed.
    /// - Parameters:
    ///   - handle: Handle used to identify the bundle on disk.
    func clean() {
        Logger.helper.log("Cleaning up VM \(handle).")
        do {
            // Remove working (ephemeral) VMs only.
            try vmManager.removeWorkingVM(handle: config.handle)
            Logger.helper.log("Cleaned up VM \(handle).")
        } catch {
            Logger.helper.error("Failure when removing VM files: \(error)")
        }
    }
}
