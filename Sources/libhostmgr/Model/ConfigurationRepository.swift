import Foundation

public struct ConfigurationRepository {

    public static var configurationFileExists: Bool {
        FileManager.default.fileExists(at: Paths.configurationFilePath)
    }

    public static func createConfigurationDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(at: Paths.configurationRoot, withIntermediateDirectories: true)
    }

    public static func getConfiguration() throws -> Configuration {
        try createConfigurationDirectoryIfNeeded()
        let data = try Data(contentsOf: Paths.configurationFilePath)
        return try Configuration.from(data: data)
    }

    @discardableResult
    public static func write(configuration: Configuration) throws -> Configuration {
        try createConfigurationDirectoryIfNeeded()

        let data = try jsonEncoder.encode(configuration)
        try data.write(to: Paths.configurationFilePath)

        return configuration
    }

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
}
