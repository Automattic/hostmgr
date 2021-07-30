import Foundation
import SotoS3
import ArgumentParser

enum SchedulableSyncCommand: String, Codable, CaseIterable, ExpressibleByArgument {
    case authorized_keys = "authorized_keys"
    case vm_images = "vm_images"
}

struct Configuration: Codable {
    var version = 1

    var syncTasks: [SchedulableSyncCommand] = [
        .authorized_keys,
        .vm_images,
    ]

    /// VM Remote Image Settings
    var vmImagesBucket: String = ""
    var vmImagesRegion: Region = .useast1
    var useVMTransferAcceleration: Bool = false

    /// Images that are protected from deletion (useful for local work, or for a fallback image)
    var protectedImages: [String] = []
    private var localImageStorageDirectory: String = "/usr/local/var/vm-images"
    var vmStorageDirectory: URL {
        URL(fileURLWithPath: localImageStorageDirectory)
    }

    /// authorized_keys file sync
    var authorizedKeysSyncInterval: Int = 3600
    var authorizedKeysBucket: String = ""
    var authorizedKeysRegion: Region = .useast1
    var localAuthorizedKeys: String = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".ssh")
        .appendingPathComponent("authorized_keys")
        .path

    /// git repo mirroring
    var gitMirrorBucket: String = ""
    private var localGitMirrorStorageDirectory: String = "/usr/local/var/git-mirrors"
    var gitMirrorDirectory: URL {
        URL(fileURLWithPath: localGitMirrorStorageDirectory)
    }
    var gitMirrorPort: UInt = 41362

    static var shared: Configuration = (try? StateManager.getConfiguration()) ?? Configuration()

    @discardableResult
    mutating func addSyncTask(_ task: SchedulableSyncCommand) throws -> Configuration {
        self.syncTasks.append(task)
        return self
    }

    @discardableResult
    func save() throws -> Configuration {
        return try StateManager.write(configuration: self)
    }
}

struct StateManager {

    private static let configurationDirectory = URL(fileURLWithPath: "/usr/local/etc/hostmgr")
    private static let filename = "config.json"

    private static var configurationPath: URL {
        configurationDirectory.appendingPathComponent(filename)
    }

    private static var stateDirectory: URL {
        URL(fileURLWithPath: "/usr/local/var/hostmgr").appendingPathComponent("state")
    }

    static var configurationFileExists: Bool {
        FileManager.default.fileExists(atPath: configurationPath.path)
    }

    static func getConfiguration() throws -> Configuration {
        try FileManager.default.createDirectory(at: configurationDirectory, withIntermediateDirectories: true)
        let data = try Data(contentsOf: configurationPath)
        return try JSONDecoder().decode(Configuration.self, from: data)
    }

    @discardableResult
    static func write(configuration: Configuration) throws -> Configuration {
        try FileManager.default.createDirectory(at: configurationDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configuration)
        try data.write(to: configurationPath)
        return configuration
    }

    static func load<T>(key: String) throws -> T where T: Codable {
        let url = stateDirectory.appendingPathComponent(key)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func store<T>(key: String, value: T) throws where T: Codable {
        let url = stateDirectory.appendingPathComponent(key)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(value)
        try data.write(to: url)
    }
}
