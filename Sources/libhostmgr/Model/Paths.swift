import Foundation

public struct Paths {

    private static let storageDirectoryIdentifier = "com.automattic.hostmgr"

    static var storageRoot: URL {
        #if arch(arm64)
        URL(fileURLWithPath: "/opt/hostmgr", isDirectory: true)
        #else
        URL(fileURLWithPath: "/usr/local", isDirectory: true)
        #endif
    }

    static var configurationRoot: URL {
        #if arch(arm64)
        storageRoot
        #else
        storageRoot
            .appendingPathComponent("etc", isDirectory: true)
            .appendingPathComponent("hostmgr", isDirectory: true)

        #endif
    }

    static var stateRoot: URL {
        #if arch(arm64)
        storageRoot.appendingPathComponent("state", isDirectory: true)
        #else
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
        #endif
    }

    public static var vmImageStorageDirectory: URL {
        #if arch(arm64)
        storageRoot.appendingPathComponent("vm-images", isDirectory: true)
        #else
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("vm-images")
        #endif
    }

    public static var ephemeralVMStorageDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("virtual-machines")
    }

    public static var gitMirrorStorageDirectory: URL {
        #if arch(arm64)
        storageRoot.appendingPathComponent("git-mirrors", isDirectory: true)
        #else
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("git-mirrors", isDirectory: true)
        #endif
    }

    public static var restoreImageDirectory: URL {
        storageRoot.appendingPathComponent("restore-images", isDirectory: true)
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

    public static var buildkiteVMRootDirectory: URL {
        #if arch(arm64)
        storageRoot.appendingPathComponent("buildkite", isDirectory: true)
        #else
        URL(fileURLWithPath: "/usr/local/var/buildkite-agent")
        #endif
    }

    public static var buildkiteBuildDirectory: URL {
        buildkiteVMRootDirectory.appendingPathComponent("builds")
    }

    public static var buildkiteHooksDirectory: URL {
        buildkiteVMRootDirectory.appendingPathComponent("hooks")
    }

    public static var buildkitePluginsDirectory: URL {
        buildkiteVMRootDirectory.appendingPathComponent("plugins")
    }
}
