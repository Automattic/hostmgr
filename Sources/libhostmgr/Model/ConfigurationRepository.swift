import Foundation

public struct ConfigurationRepository {

    private static var configurationDirectory: URL {
        switch ProcessInfo.processInfo.processorArchitecture {
        case .arm64: return URL(fileURLWithPath: "/opt/homebrew/etc/hostmgr")
        case .x64: return URL(fileURLWithPath: "/usr/local/etc/hostmgr")
        }
    }

    private static let filename = "config.json"

    private static var configurationPath: URL {
        configurationDirectory.appendingPathComponent(filename)
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
}
