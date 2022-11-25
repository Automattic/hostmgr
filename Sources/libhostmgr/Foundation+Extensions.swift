import Foundation

enum ProcessorArchitecture: String {
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
        let output = Pipe()

        do {
            let task = Process()
            task.launchPath = "/usr/sbin/sysctl"
            task.arguments = ["-n", "hw.physicalcpu"]
            task.standardOutput = output
            try task.run()

            let cpuCountData = output.fileHandleForReading.readDataToEndOfFile()
            let cpuCountString = String(
                data: cpuCountData,
                encoding: .utf8
            )!.trimmingCharacters(in: .whitespacesAndNewlines)

            return Int(cpuCountString) ?? self.processorCount
        } catch _ {
            // Fall back to returning the count including SMT cores
            return self.processorCount
        }
    }
}

extension FileManager {
    public func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path) && !directoryExists(at: url)
    }

    public func directoryExists(at url: URL) -> Bool {
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
        displayName(atPath: url.path)
    }

    public func createFile(at url: URL, contents: Data) throws {
        createFile(atPath: url.path, contents: contents)
    }

    public func removeItemIfExists(at url: URL) throws {
        guard fileExists(at: url) else {
            return
        }

        try removeItem(at: url)
    }
}

extension URL {
    public static var tempFilePath: URL {
        FileManager.default.temporaryFilePath()
    }
}

extension NSRange {
    public static func forString(_ string: String) -> NSRange {
        NSRange(string.startIndex..<string.endIndex, in: string)
    }
}

extension NSRegularExpression {
    public var captureGroupNames: [String] {
        let regex = try! NSRegularExpression(pattern: #"\?{1}\<(\w+)>"#)
        return regex.matches(in: self.pattern, range: .forString(self.pattern))
            .compactMap { Range($0.range(at: 1), in: self.pattern) }
            .map { String(self.pattern[$0]) }
    }

    public func namedMatches(in string: String) -> [String: String] {
        var matches = [String: String]()
        for captureGroupName in self.captureGroupNames {
            for match in self.matches(in: string, range: NSRange.forString(string)) {
                let range = match.range(withName: captureGroupName)
                if let range = Range(range, in: string) {
                    matches[captureGroupName] = String(string[range])
                }
            }
        }
        return matches
    }

    func firstMatch(named name: String, in string: String) -> String? {
        guard let match = self.matches(in: string, range: .forString(string)).first else {
            return nil
        }

        return (string as NSString).substring(with: match.range(withName: name))
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
