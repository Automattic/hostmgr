import Foundation
import ArgumentParser
import libhostmgr

extension FileManager {

    func createTemporaryFile(containing string: String = "") throws -> URL {
        let file = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try string.write(to: file, atomically: false, encoding: .utf8)
        return file
    }

    func directoryExists(atUrl url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func createDirectoryTree(atUrl url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func subpaths(at url: URL) -> [String] {
        self.subpaths(atPath: url.path) ?? []
    }

    func displayName(at url: URL) -> String {
        displayName(atPath: url.path)
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
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}

extension ProcessInfo {

    var physicalProcessorCount: Int {
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

func to(_ callback: @autoclosure () throws -> Void, unless conditional: Bool) rethrows {
    guard conditional == false else {
        return
    }

    try callback()
}
