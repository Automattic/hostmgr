import Foundation

public struct Paths {

    private static let storageDirectoryIdentifier = "com.automattic.hostmgr"

    static var storageRoot: URL {
        #if arch(arm64)
        arm64StorageRoot.appendingPathComponent(storageDirectoryIdentifier, isDirectory: true)
        #else
        URL(fileURLWithPath: "/usr/local", isDirectory: true).appendingPathComponent("var", isDirectory: true)
        #endif
    }

    /// A way to push the available check out to keep things pretty
    private static var arm64StorageRoot: URL {
        guard #available(macOS 13.0, *) else {
            preconditionFailure("Apple Silicon in CI should only run on macOS 13 or greater")
        }

        return URL.applicationSupportDirectory
    }

    static var configurationRoot: URL {
        #if arch(arm64)
        storageRoot.appendingPathComponent("configuration")
        #else
        storageRoot
            .appendingPathComponent("etc", isDirectory: true)
            .appendingPathComponent("hostmgr", isDirectory: true)
        #endif
    }

    static var stateRoot: URL {
        #if arch(arm64)
        storageRoot.appendingPathComponent("state")
        #else
        storageRoot
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
        #endif
    }

    public static var vmImageStorageDirectory: URL {
        storageRoot.appendingPathComponent("vm-images")
    }

    public static var gitMirrorStorageDirectory: URL {
        storageRoot.appendingPathComponent("git-mirrors")
    }

    public static var authorizedKeysFilePath: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
            .appendingPathComponent("authorized_keys")
    }

    static var configurationFilePath: URL {
        configurationRoot.appendingPathComponent("config.json")
    }

    public static func toAppleSiliconVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("bundle")
    }

    public static func toArchivedVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("aar")
    }
}
