import Foundation
import ArgumentParser
import libhostmgr

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
