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
}

extension FileManager {
    public func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }

    public func directoryExists(at url: URL) throws -> Bool {
        var isDir: ObjCBool = true
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    public func createTemporaryFile(containing string: String = "") throws -> URL {
        let path = temporaryFilePath()
        try string.write(to: path, atomically: false, encoding: .utf8)
        return path
    }

    public func temporaryFilePath() -> URL {
        self.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".tmp")
    }

    public func createDirectoryTree(atUrl url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
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
