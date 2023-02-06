import Foundation

public struct Paths {

    private static var homebrewRoot: URL {
        switch ProcessInfo.processInfo.processorArchitecture {
        case .arm64: return URL(fileURLWithPath: "/opt/homebrew", isDirectory: true)
        case .x64: return URL(fileURLWithPath: "/usr/local", isDirectory: true)
        }
    }

    static var storageRoot: URL {
        homebrewRoot.appendingPathComponent("var", isDirectory: true)
    }

    static var configurationRoot: URL {
        homebrewRoot
            .appendingPathComponent("etc", isDirectory: true)
            .appendingPathComponent("hostmgr", isDirectory: true)
    }

    static var stateRoot: URL {
        storageRoot
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
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
        FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("aar")
    }
}
