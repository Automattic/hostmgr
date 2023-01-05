import Foundation

public struct ConfigurationRepository {

    public static var configurationFileExists: Bool {
        FileManager.default.fileExists(at: Paths.configurationFilePath)
    }

    public static func getConfiguration() throws -> Configuration {
        try FileManager.default.createDirectory(at: Paths.configurationRoot, withIntermediateDirectories: true)
        let data = try Data(contentsOf: Paths.configurationFilePath)
        return try Configuration.from(data: data)
    }

    @discardableResult
    public static func write(configuration: Configuration) throws -> Configuration {
        try FileManager.default.createDirectory(at: Paths.configurationRoot, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configuration)
        try data.write(to: Paths.configurationFilePath)
        return configuration
    }
}
