import Foundation

public actor StatsRepository {
    public enum ResourceCategory: String {
        case virtualMachine
        case gitMirror
        case cache
    }

    struct UsageLine {
        let version: String = "v1"
        let name: String
        let category: ResourceCategory
        let date: Date

        func toLine() -> String {
            [
                self.version,
                self.name,
                self.category.rawValue,
                ISO8601DateFormatter().string(from: self.date)
            ].joined(separator: "+").padding(toLength: 127, withPad: " ", startingAt: 0) + "\n"
        }

        func toData() -> Data {
            Data(self.toLine().utf8)
        }

        private static let dateFormatter = ISO8601DateFormatter()

        static func from(data: Data) -> UsageLine? {
            guard
                let components = String(data: data, encoding: .utf8)?.trimmingWhitespace.components(separatedBy: "+"),
                !components.isEmpty,
                let version = components.first,
                !version.isEmpty
            else {
                return nil
            }

            let name = String(components[1])
            let categoryString = String(components[2])
            let dateString = String(components[3])

            guard
                let category = ResourceCategory(rawValue: categoryString),
                let date = dateFormatter.date(from: dateString)
            else {
                return nil
            }

            return UsageLine(name: name, category: category, date: date)
        }
    }

    private let usageFile: URL

    public init(usageFile: URL = URL(fileURLWithPath: "/usr/local/var/hostmgr/usage")) {
        self.usageFile = usageFile
    }

    public func recordResourceUsage(for name: String, category: ResourceCategory, date: Date = Date()) throws {
        let data = UsageLine(name: name, category: category, date: date).toData()

        if !FileManager.default.fileExists(at: self.usageFile) {
            try FileManager.default.createFile(at: usageFile, contents: data)
            return
        } else {
            let fileHandle = try FileHandle(forWritingTo: self.usageFile)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try fileHandle.close()
        }
    }

    public func lookupLatestUsageForResource(withName name: String, for category: ResourceCategory) throws -> Date? {
        let reader = try StreamingFileReader(url: self.usageFile, bufferSize: 128) // 128-byte buffer to match UsageLine

        var latestUsage: Date?

        while let data = reader.stream() {
            guard let line = UsageLine.from(data: data) else {
                continue
            }

            if latestUsage ?? Date.distantPast < line.date {
                latestUsage = line.date
            }
        }

        return latestUsage
    }
}
