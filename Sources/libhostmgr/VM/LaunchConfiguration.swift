import Foundation
import Virtualization

/// An object describing the runtime configuration properties available to a VM
///
/// These are distinct from the options baked into its internal configuration
public struct LaunchConfiguration: Codable {

    public struct SharedPath: Codable {
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
        self.handle = handle
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

    func toJSON() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let jsonString = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.coderReadCorrupt)
        }
        return jsonString
    }

    public static func from(string: String) throws -> LaunchConfiguration {
        try JSONDecoder().decode(Self.self, from: Data(string.utf8))
    }
}
