import Foundation
import ArgumentParser

extension FileManager {

    func createTemporaryFile(containing string: String = "") throws -> URL {
        let file = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try string.write(to: file, atomically: false, encoding: .utf8)
        return file
    }

    func directoryExists(atUrl url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory:&isDirectory)
        return exists && isDirectory.boolValue
    }

    func createDirectoryTree(atUrl url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func subpaths(at url: URL) -> [String] {
        self.subpaths(atPath: url.path) ?? []
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(fileURLWithPath: argument)
    }

    var basename: String {
        (lastPathComponent as NSString).deletingPathExtension
    }
}

extension String {
    func escapingQuotes() -> Self {
        self.replacingOccurrences(of: "\"", with: "\\\"")
    }

    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}
