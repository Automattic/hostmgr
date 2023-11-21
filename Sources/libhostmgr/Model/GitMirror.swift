import Foundation
import ArgumentParser

public struct GitMirror {

    enum Errors: Error, LocalizedError {
        case unableToFindURLInEnvironment(key: String)

        var errorDescription: String? {
            switch self {
            case .unableToFindURLInEnvironment(let key):
                return "Unable to find Git Mirror URL in environment using key `\(key)`"
            }
        }
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var slug: String {
        url.absoluteString.slugify()
    }

    public var localPath: URL {
        Paths.gitMirrorStorageDirectory.appendingPathComponent(slug)
    }

    public var archivePath: URL {
        Paths.tempFilePath.appendingPathComponent(remoteFilename)
    }

    public var remoteFilename: String {
        calculateRemoteFilename(given: .now)
    }

    func calculateRemoteFilename(given date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM"

        return slug + "-" + formatter.string(from: date) + ".aar"
    }

    /// Does this Git Mirror exist on disk?
    ///
    public var existsLocally: Bool {
        get throws {
            return try FileManager.default.directoryExists(at: localPath)
        }
    }

    /// Does this Git Mirror's archive exist on disk?
    ///
    public var archiveExistsLocally: Bool {
        get throws {
            try ensureTempDirectoryExists()
            return FileManager.default.fileExists(at: archivePath)
        }
    }

    public func compress() throws {
        try ensureTempDirectoryExists()

        try Compressor.compress(
            directory: localPath,
            to: archivePath
        )
    }

    public func decompress() throws {
        try Compressor.decompress(
            archiveAt: archivePath,
            to: localPath
        )
    }

    public static func fromEnvironment(
        key: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> GitMirror {
        guard
            let urlString = environment[key],
            let url = URL(string: urlString)
        else {
            throw Errors.unableToFindURLInEnvironment(key: key)
        }

        return GitMirror(url: url)
    }

    public static func from(string: String) -> GitMirror? {
        guard let url = URL(string: string) else {
            return nil
        }

        return GitMirror(url: url)
    }

    func ensureTempDirectoryExists() throws {
        let archiveParentDirectory = archivePath.deletingLastPathComponent()

        if try !FileManager.default.directoryExists(at: archiveParentDirectory) {
            try FileManager.default.createDirectory(at: archiveParentDirectory, withIntermediateDirectories: true)
        }
    }
}

extension GitMirror: ExpressibleByArgument {
    public init?(argument: String) {
        guard let value = GitMirror.from(string: argument) else {
            return nil
        }

        self = value
    }
}
