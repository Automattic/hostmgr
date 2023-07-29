import Foundation

public struct Paths {

    private static let storageDirectoryIdentifier = "com.automattic.hostmgr"

    static var storageRoot: URL {
        #if arch(arm64)
        URL(fileURLWithPath: "/opt/a8c-ci", isDirectory: true)
        #else
        URL(fileURLWithPath: "/usr/local", isDirectory: true)
        #endif
    }

    static var configurationRoot: URL {
        storageRoot
            .appendingPathComponent("etc", isDirectory: true)
            .appendingPathComponent("hostmgr", isDirectory: true)
    }

    static var stateRoot: URL {
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
    }

    public static var vmImageStorageDirectory: URL {
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("vm-images")
    }

    public static var ephemeralVMStorageDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("virtual-machines")
    }

    public static var gitMirrorStorageDirectory: URL {
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("git-mirrors", isDirectory: true)
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

    static var applicationCacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(storageDirectoryIdentifier)
    }

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(storageDirectoryIdentifier)
    }

    public static var userLaunchAgentsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("LaunchAgents")
    }

    public static var logsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Logs")
            .appendingPathComponent(storageDirectoryIdentifier)
    }

    public static func toAppleSiliconVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("bundle")
    }

    public static func toVMTemplate(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("vmtemplate")
    }

    public static func toArchivedVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("aar")
    }

    public static func createEphemeralVMStorageIfNeeded() throws {
        guard try !FileManager.default.directoryExists(at: ephemeralVMStorageDirectory) else {
            return
        }

        try FileManager.default.createDirectory(at: ephemeralVMStorageDirectory, withIntermediateDirectories: true)
    }
}

extension Paths {

    public static func buildkiteVMRootDirectory(forUser user: String) -> URL {
        #if arch(arm64)
        URL(fileURLWithPath: "/Users").appendingPathComponent(user)
        #else
        URL(fileURLWithPath: "/usr/local/var/buildkite-agent")
        #endif
    }

    public static func buildkiteBuildDirectory(forUser user: String) -> URL {
        buildkiteVMRootDirectory(forUser: user).appendingPathComponent("builds")
    }

    public static func buildkiteHooksDirectory(forUser user: String) -> URL {
        buildkiteVMRootDirectory(forUser: user).appendingPathComponent("hooks")
    }

    public static func buildkitePluginsDirectory(forUser user: String) -> URL {
        buildkiteVMRootDirectory(forUser: user).appendingPathComponent("plugins")
    }
}
