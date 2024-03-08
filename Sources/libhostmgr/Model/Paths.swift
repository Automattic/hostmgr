import Foundation

public struct Paths {

    private static let storageDirectoryIdentifier = "com.automattic.hostmgr"

    static var storageRoot: URL {
        URL(fileURLWithPath: "/opt/ci", isDirectory: true)
    }

    static var configurationRoot: URL {
        storageRoot
    }

    static var stateRoot: URL {
        storageRoot
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
    }

    public static var vmImageStorageDirectory: URL {
        storageRoot.appendingPathComponent("vm-images", isDirectory: true)
    }

    public static var tempDirectory: URL {
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
    }

    public static var ephemeralVMStorageDirectory: URL {
        tempDirectory.appendingPathComponent("virtual-machines", isDirectory: true)
    }

    public static var vmWorkingStorageDirectory: URL {
        storageRoot.appendingPathComponent("working-vm-images")
    }

    public static var gitMirrorStorageDirectory: URL {
        storageRoot.appendingPathComponent("git-mirrors", isDirectory: true)
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
        storageRoot.appendingPathComponent("hostmgr.json")
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

    public static let vmUsageFile = stateRoot.appending(path: "vm-usage")

    public static func toAppleSiliconVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("bundle")
    }

    public static func toWorkingAppleSiliconVM(named name: String) -> URL {
        Paths.vmWorkingStorageDirectory.appendingPathComponent(name).appendingPathExtension("bundle")
    }

    public static func toWorkingParallelsVM(named name: String) -> URL {
        Paths.vmWorkingStorageDirectory.appendingPathComponent(name).appendingPathExtension("pvm")
    }

    public static func toVMTemplate(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("vmtemplate")
    }

    public static func toArchivedVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("vmtemplate")
            .appendingPathExtension("aar")
    }

    public static func toGitMirror(atURL url: URL) -> URL {
        gitMirrorStorageDirectory.appendingPathComponent(url.absoluteString.slugify())
    }
}

extension Paths {

    public static var buildkiteBuildDirectory: URL {
        storageRoot.appendingPathComponent("builds")
    }

    public static var buildkiteHooksDirectory: URL {
        storageRoot.appendingPathComponent("hooks")
    }

    public static var buildkitePluginsDirectory: URL {
        storageRoot.appendingPathComponent("plugins")
    }
}
