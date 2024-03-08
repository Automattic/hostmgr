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
}

// Public Paths to hostmgr-specific directories
public extension Paths {
    static let vmUsageFile = stateRoot.appendingPathComponent("vm-usage")

    static let vmImageStorageDirectory: URL = {
        storageRoot.appendingPathComponent("vm-images", isDirectory: true)
    }()

    static let ephemeralVMStorageDirectory: URL = {
        tempDirectory.appendingPathComponent("virtual-machines", isDirectory: true)
    }()

    static let vmWorkingStorageDirectory: URL = {
        storageRoot.appendingPathComponent("working-vm-images")
    }()

    static let gitMirrorStorageDirectory: URL = {
        storageRoot.appendingPathComponent("git-mirrors", isDirectory: true)
    }()

    static let restoreImageDirectory: URL = {
        storageRoot.appendingPathComponent("restore-images", isDirectory: true)
    }()
}

// System Paths outside `/opt/ci`
public extension Paths {
    static let authorizedKeysFilePath: URL = {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
            .appendingPathComponent("authorized_keys")
    }()

    static let userLaunchAgentsDirectory: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("LaunchAgents")
    }()

    static let logsDirectory: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Logs")
            .appendingPathComponent(storageDirectoryIdentifier)
    }()
}

// Functions to get Paths to a specific VM name or repo
public extension Paths {
    static func toAppleSiliconVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("bundle")
    }

    static func toWorkingAppleSiliconVM(named name: String) -> URL {
        Paths.vmWorkingStorageDirectory.appendingPathComponent(name).appendingPathExtension("bundle")
    }

    static func toWorkingParallelsVM(named name: String) -> URL {
        Paths.vmWorkingStorageDirectory.appendingPathComponent(name).appendingPathExtension("pvm")
    }

    static func toVMTemplate(named name: String) -> URL {
        Paths.vmImageStorageDirectory.appendingPathComponent(name).appendingPathExtension("vmtemplate")
    }

    static func toArchivedVM(named name: String) -> URL {
        Paths.vmImageStorageDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("vmtemplate")
            .appendingPathExtension("aar")
    }

    static func toGitMirror(atURL url: URL) -> URL {
        gitMirrorStorageDirectory.appendingPathComponent(url.absoluteString.slugify())
    }
}

// Paths needed by Buildkite's own config
public extension Paths {
    static let buildkiteBuildDirectory: URL = {
        storageRoot.appendingPathComponent("builds")
    }()

    static let buildkiteHooksDirectory: URL = {
        storageRoot.appendingPathComponent("hooks")
    }()

    static let buildkitePluginsDirectory: URL = {
        storageRoot.appendingPathComponent("plugins")
    }()

    static let buildkiteSocketsDirectory: URL = {
        tempDirectory.appendingPathComponent("sockets")
    }()
}
