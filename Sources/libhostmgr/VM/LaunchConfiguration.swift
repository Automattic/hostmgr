import Foundation
import Virtualization
import OSLog

/// An object describing the runtime configuration properties available to a VM
///
/// These are distinct from the options baked into its internal configuration
public struct LaunchConfiguration: Sendable, Codable {

    public struct SharedPath: Sendable, Codable {
        let source: URL
        let readOnly: Bool

        public init(source: URL, readOnly: Bool = true) {
            self.source = source
            self.readOnly = readOnly
        }
    }

    /// The name of the VM to launch
    public let name: String

    /// The VM handle – the cloned VM will use this handle, allowing multiple VMs with the same name
    /// to be launched and individually terminated as needed
    ///
    /// If the `LaunchConfiguration` is set to "persistent", the handle will always be the same as the `name` (thus,
    /// it's impossible to launch two persistent VMs with the same name).
    public let handle: String

    /// Launch the VM persistently
    ///
    /// Setting this flag to `true` will skip creating an ephemeral copy of this VM – instead, it will
    /// boot the VM image directly, causing any changes made to the VM to persist after shutdown.
    /// This is useful for creating VM templates.
    public let persistent: Bool

    /// Paths that should be mounted into the VM
    ///
    /// Uses appropriate folder-sharing mechanisms to mirror host directories into the VM on launch. Useful for caches.
    public let sharedPaths: [SharedPath]

    /// Don't wait for networking – this is particularly useful for debugging issues with DHCPd and NAT networking
    ///
    public let waitForNetworking: Bool

    public init(
        name: String,
        handle: String,
        persistent: Bool = false,
        sharedPaths: [SharedPath] = [],
        waitForNetworking: Bool = true
    ) {
        self.name = name
        self.handle = persistent ? name : handle
        self.persistent = persistent
        self.sharedPaths = sharedPaths
        self.waitForNetworking = waitForNetworking

        Logger.lib.debug(
"""
== Initialized launch Configuration ==
Name:        \(name)
Handle:      \(handle)
Persistence: \(persistent)
"""
        )
    }

    public var sharedDirectoryConfiguration: VZDirectorySharingDeviceConfiguration {
        let tag = VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag

        let sharingConfiguration = VZVirtioFileSystemDeviceConfiguration(tag: tag)
        sharingConfiguration.share = VZMultipleDirectoryShare(directories: sharedDirectories)

        return sharingConfiguration
    }

    var sharedDirectories: [String: VZSharedDirectory] {
        sharedPaths.reduce(into: [String: VZSharedDirectory]()) {
            $0[$1.source.lastPathComponent] = VZSharedDirectory(url: $1.source, readOnly: $1.readOnly)
        }
    }

    var vmSourcePath: URL {
        get throws {
            try VMResolver.resolveBundle(named: self.name).root
        }
    }

    var destinationPath: URL {
        if self.persistent {
            return Paths.toAppleSiliconVM(named: self.handle)
        } else {
            let path = Paths.toWorkingAppleSiliconVM(named: self.handle)
            Logger.lib.debug("Destination to non-persitent VM is: \(path)")
            return path
        }
    }

    public func setupVirtualMachine() async throws -> VZVirtualMachine {
        let sourceBundle = try VMBundle(at: vmSourcePath)
        let bundle = self.persistent
            ? sourceBundle
            : try VMResolver.resolveBundle(named: name).createEphemeralCopy(at: destinationPath)

        Logger.helper.debug("""
==Resolved VM Bundle as VM Configuration Source==
Persistent Launch Requested:    \(self.persistent)
Source Path:                    \(bundle.root)
Source MAC Address:             \(sourceBundle.macAddress)
Destination MAC Adddress:       \(bundle.macAddress)
""")

        let configuration = try bundle.virtualMachineConfiguration()
        configuration.directorySharingDevices = [self.sharedDirectoryConfiguration]
        try configuration.validate()

        Logger.helper.debug("""
==VM Configuration Prepared==
CPU Count:      \(configuration.cpuCount)
MAC Address:    \(String(describing: configuration.networkDevices.first?.macAddress))
""")

        return VZVirtualMachine(configuration: configuration)
    }
}

// MARK: Packing and unpacking across the XPC bridge
extension LaunchConfiguration {

    public func packed() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func unpack(_ data: Data) throws -> LaunchConfiguration {
        try JSONDecoder().decode(LaunchConfiguration.self, from: data)
    }
}
