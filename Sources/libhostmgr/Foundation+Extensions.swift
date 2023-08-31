import Foundation
import CryptoKit

public enum ProcessorArchitecture: String {
    case arm64
    case x64 = "x86_64"
}

extension ProcessInfo {
    var processorArchitecture: ProcessorArchitecture {
        var sysinfo = utsname()
        uname(&sysinfo)
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        let identifier = String(bytes: data, encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        return ProcessorArchitecture(rawValue: identifier)!
    }

    public var physicalProcessorCount: Int {
        var size: size_t = MemoryLayout<Int>.size
        var coresCount: Int = 0
        sysctlbyname("hw.physicalcpu", &coresCount, &size, nil, 0)
        return coresCount
    }

    var isIntelArchitecture: Bool {
        processorArchitecture == .x64
    }

    var isAppleSilicon: Bool {
        processorArchitecture == .arm64
    }
}

extension FileManager {
    public func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }

    public func directoryExists(at url: URL) throws -> Bool {
        var isDir: ObjCBool = true
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    public func availableStorageSpace(forVolumeContainingDirectoryAt url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    public func size(ofObjectAt url: URL) throws -> Int {

        var isDir: ObjCBool = true
        guard fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if isDir.boolValue {
            return try directorySize(of: url)
        } else {
            return try fileSize(of: url)
        }
    }

    func fileSize(of url: URL) throws -> Int {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return values.fileSize!
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

    public func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAt path: URL) throws {
        try self.setAttributes(attributes, ofItemAtPath: path.path)
    }

    public func setBundleBit(forDirectoryAt url: URL, to value: Bool) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isPackage = value

        var urlCopy = url
        try urlCopy.setResourceValues(resourceValues)
    }
}

extension Data {
    var sha256: Data {
        var hasher = SHA256()
        hasher.update(data: self)
        return Data(hasher.finalize())
    }
}

extension Date {
    /// Required until we only support macOS 12
    static var now: Date {
        return Date()
    }
}

extension String {
    public var trimmingWhitespace: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { lhs, rhs in
            return lhs[keyPath: keyPath] < rhs[keyPath: keyPath]
        }
    }
}

extension String {

    public func slugify() -> String {
        self.components(separatedBy: .alphanumerics.inverted).joined(separator: "-")
    }
}

extension Progress {
    func estimateThroughput(fromTimeElapsed elapsedTime: TimeInterval) {
        guard Int64(elapsedTime) > 0 else {
            self.setUserInfoObject(0, forKey: .throughputKey)
            self.setUserInfoObject(TimeInterval.infinity, forKey: .estimatedTimeRemainingKey)
            return
        }

        let unitsPerSecond = self.completedUnitCount.quotientAndRemainder(dividingBy: Int64(elapsedTime)).quotient
        let throughput = Int(unitsPerSecond)
        self.setUserInfoObject(throughput, forKey: .throughputKey)

        guard throughput > 0 else {
            self.setUserInfoObject(TimeInterval.infinity, forKey: .estimatedTimeRemainingKey)
            return
        }

        let unitsRemaining = self.totalUnitCount - self.completedUnitCount
        let secondsRemaining = unitsRemaining.quotientAndRemainder(dividingBy: Int64(throughput)).quotient

        self.setUserInfoObject(TimeInterval(secondsRemaining), forKey: .estimatedTimeRemainingKey)
    }
}

public func to(_ callback: @autoclosure () throws -> Void, if conditional: Bool) rethrows {
    guard conditional == true else {
        return
    }

    try callback()
}

public func to(_ callback: @autoclosure () throws -> Void, unless conditional: Bool) rethrows {
    guard conditional == false else {
        return
    }

    try callback()
}
