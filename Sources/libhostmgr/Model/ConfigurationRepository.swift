import Foundation

public struct ConfigurationRepository {

    enum Errors: Error {
        case configurationFileNotFound
    }

    public static var configurationFileExists: Bool {
        FileManager.default.fileExists(at: Paths.configurationFilePath)
    }

    public static func getConfiguration() throws -> Configuration {
        try createConfigurationDirectoryIfNeeded()

        guard FileManager.default.fileExists(at: Paths.configurationFilePath) else {
            throw HostmgrError.missingConfigurationFile(Paths.configurationFilePath)
        }

        let data = try Data(contentsOf: Paths.configurationFilePath)
        return try Configuration.from(data: data)
    }

    static func createConfigurationDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: Paths.configurationRoot.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    public static func write(configuration: Configuration) throws -> Configuration {

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
