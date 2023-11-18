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
    let sharedPaths: [SharedPath]

    public init(name: String, handle: String, persistent: Bool = false, sharedPaths: [SharedPath] = []) {
        self.name = name
        self.handle = persistent ? name : handle
        self.persistent = persistent
        self.sharedPaths = sharedPaths
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
            return Paths.toWorkingAppleSiliconVM(named: self.handle)
        }
    }

    public func createBundle() throws -> VMBundle {
        if self.persistent {
            return try VMBundle(at: vmSourcePath)
        }

        return try VMResolver.resolveBundle(named: name)
            .createEphemeralCopy(at: destinationPath)
    }

    public func setupVirtualMachine() async throws -> VZVirtualMachine {
        let configuration = try createBundle().virtualMachineConfiguration()
        configuration.directorySharingDevices = [self.sharedDirectoryConfiguration]

        try configuration.validate()

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
