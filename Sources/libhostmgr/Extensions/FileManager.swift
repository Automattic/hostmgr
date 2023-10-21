import Foundation
import System

protocol FileManagerProto {
    // swiftlint:disable identifier_name
    func fileExists(at: URL) -> Bool
    func directoryExists(at: URL) throws -> Bool
    // swiftlint:enable identifier_name
}

extension FileManager: FileManagerProto {

    public func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }

    public func directoryExists(at url: URL) throws -> Bool {
        var isDir: ObjCBool = true
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

extension FileManager {
    public func createDirectoryIfNotExists(at url: URL) throws {
        guard try !self.directoryExists(at: url) else {
            return
        }

        try self.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func createParentDirectoryIfNotExists(for url: URL) throws {
        try createDirectoryIfNotExists(at: url.deletingLastPathComponent())
    }

    public func availableStorageSpace(forVolumeContainingDirectoryAt url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    public func size(ofObjectAt url: URL) throws -> Int {
        if try directoryExists(at: url) {
            return try directorySize(of: url)
        } else {
            return try fileSize(of: url)
        }
    }

    func fileSize(of url: URL) throws -> Int {
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw CocoaError(.fileReadUnknown)
        }

        return size
    }

    /// returns total allocated size of a the directory including its subFolders or not
    func directorySize(of url: URL) throws -> Int {
        guard
            let enumerator = enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]),
            let urls = enumerator.allObjects as? [URL]
        else {
            return 0
        }

        let sizes = try urls
            .compactMap { try $0.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize }

        return sizes.reduce(0, +)
     }

    public func createTemporaryFile(containing string: String = "") throws -> URL {
        let path = temporaryFilePath()
        try string.write(to: path, atomically: false, encoding: .utf8)
        return path
    }

    public func temporaryFilePath(named name: String = UUID().uuidString + ".tmp") -> URL {
        self.temporaryDirectory.appendingPathComponent(name)
    }

    public func subpaths(at url: URL) -> [String] {
        self.subpaths(atPath: url.path) ?? []
    }

    public func displayName(at url: URL) -> String {
        self.displayName(atPath: url.path)
    }

    public func createFile(at url: URL, contents: Data) throws {
        self.createFile(atPath: url.path, contents: contents)
    }

    public func createEmptyFile(at url: URL, size: Measurement<UnitInformationStorage>) throws {

        guard !FileManager.default.fileExists(at: url) else {
            throw CocoaError(.fileWriteFileExists)
        }

        let diskFd = open(url.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)

        guard diskFd != -1 else {
            throw CocoaError(.fileReadUnknown)
        }

        guard ftruncate(diskFd, off_t(size.converted(to: .bytes).value)) == 0 else {
            throw CocoaError(.fileReadUnknown)
        }

        guard close(diskFd) == 0 else {
            throw CocoaError(.fileReadUnknown)
        }
    }

    public func removeItemIfExists(at url: URL) throws {
        guard fileExists(at: url) else {
            return
        }

        try self.removeItem(at: url)
    }

    public func set(filePermissions: FilePermissions, forItemAt path: URL) throws {
        try setAttributes([
            .posixPermissions: filePermissions.rawValue
        ], ofItemAt: path)
    }

    public func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAt path: URL) throws {
        try self.setAttributes(attributes, ofItemAtPath: path.path)
    }

    public func setBundleBit(forDirectoryAt url: URL, to value: Bool) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isPackage = value

        var urlCopy = url
        try urlCopy.setResourceValues(resourceValues)
    }

    public func children(ofDirectory directory: URL) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(atPath: directory.path)
            .map { URL(fileURLWithPath: $0, relativeTo: directory) }
    }

}
