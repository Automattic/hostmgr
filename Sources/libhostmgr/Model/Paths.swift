import Foundation

public struct Paths {
    private static let storageDirectoryIdentifier = "com.automattic.hostmgr"

    static let storageRoot: URL = URL(fileURLWithPath: "/opt/ci", isDirectory: true)

    static let configurationRoot: URL = storageRoot

    static let configurationFilePath: URL = {
        configurationRoot.appendingPathComponent("hostmgr.json")
    }()

    public static let tempDirectory: URL = {
        storageRoot
            .appendingPathComponent("var", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
    }()

    static let stateRoot: URL = {
        storageRoot
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
    }()
    
    public static let vmUsageFile = stateRoot.appendingPathComponent("vm-usage")

    public static let vmImageStorageDirectory: URL = {
        storageRoot.appendingPathComponent("vm-images", isDirectory: true)
    }()

    public static let ephemeralVMStorageDirectory: URL = {
        tempDirectory.appendingPathComponent("virtual-machines", isDirectory: true)
    }()

    public static let vmWorkingStorageDirectory: URL = {
        storageRoot.appendingPathComponent("working-vm-images")
    }()

    public static let gitMirrorStorageDirectory: URL = {
        storageRoot.appendingPathComponent("git-mirrors", isDirectory: true)
    }()

    public static let restoreImageDirectory: URL = {
        storageRoot.appendingPathComponent("restore-images", isDirectory: true)
    }()
}

// Other Paths outside `/opt/ci`
extension Paths {
    public static let authorizedKeysFilePath: URL = {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
            .appendingPathComponent("authorized_keys")
    }()

    public static let userLaunchAgentsDirectory: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("LaunchAgents")
    }()

    public static let logsDirectory: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Logs")
            .appendingPathComponent(storageDirectoryIdentifier)
    }()
}

// Functions to get Paths to a specific VM name or repo
extension Paths {
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

// Paths needed by Buildkite's own config
extension Paths {
    public static let buildkiteBuildDirectory: URL = {
        storageRoot.appendingPathComponent("builds")
    }()

    public static let buildkiteHooksDirectory: URL = {
        storageRoot.appendingPathComponent("hooks")
    }()

    public static let buildkitePluginsDirectory: URL = {
        storageRoot.appendingPathComponent("plugins")
    }()
}
