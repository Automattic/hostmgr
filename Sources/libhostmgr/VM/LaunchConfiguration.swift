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

    public let name: String
    let sharedPaths: [SharedPath]

    public init(name: String, sharedPaths: [SharedPath]) {
        self.name = name
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
