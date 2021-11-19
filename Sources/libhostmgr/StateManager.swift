import Foundation

public struct StateManager {

    private static var configurationDirectory: URL {
        switch ProcessInfo.processInfo.processorArchitecture {
            case .arm64: return URL(fileURLWithPath: "/opt/homebrew/etc/hostmgr")
            case .x86_64: return URL(fileURLWithPath: "/usr/local/etc/hostmgr")
        }
    }

    private static let filename = "config.json"

    private static var configurationPath: URL {
        configurationDirectory.appendingPathComponent(filename)
    }

    private static var stateDirectory: URL {
        configurationDirectory.appendingPathComponent("hostmgr").appendingPathComponent("state")
    }

    public static var configurationFileExists: Bool {
        FileManager.default.fileExists(atPath: configurationPath.path)
    }

    public static func getConfiguration() throws -> Configuration {
        try FileManager.default.createDirectory(at: configurationDirectory, withIntermediateDirectories: true)
        let data = try Data(contentsOf: configurationPath)
        return try Configuration.from(data: data)
    }

    @discardableResult
    public static func write(configuration: Configuration) throws -> Configuration {
        try FileManager.default.createDirectory(at: configurationDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configuration)
        try data.write(to: configurationPath)
        return configuration
    }

    public static func load<T>(key: String) throws -> T where T: Codable {
        let url = stateDirectory.appendingPathComponent(key)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public static func store<T>(key: String, value: T) throws where T: Codable {
        let url = stateDirectory.appendingPathComponent(key)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(value)
        try data.write(to: url)
    }
}
