import Foundation

actor VMUsageTracker {

    private let usageFilePath: URL
    private let dateFormatter = ISO8601DateFormatter()

    init(usageFilePath: URL = Paths.vmUsageFile) {
        self.usageFilePath = usageFilePath
    }

    func trackUsageOf(vm: String, on date: Date = Date()) throws {
        if !FileManager.default.fileExists(at: usageFilePath) {
            try FileManager.default.createFile(at: usageFilePath, contents: Data())
        }

        let fileHandle = try FileHandle(forWritingTo: self.usageFilePath)
        try fileHandle.seekToEnd()

        let line = vm + "\t" + self.dateFormatter.string(from: date) + "\n"
        try fileHandle.write(contentsOf: Data(line.utf8))

        try fileHandle.close()
    }

    func usageCountFor(vm: String, since date: Date) async throws -> Int {
        let fileHandle = try FileHandle(forReadingFrom: self.usageFilePath)

        var count = 0

        for try await line in fileHandle.bytes.lines {
            guard line.hasPrefix(vm), let usageRecord = await parseLine(line: line) else {
                continue
            }

            if usageRecord.isAfter(date: date) {
                count += 1
            }
        }

        try fileHandle.close()

        return count
    }

    func usageStats() async throws -> [VMUsageRecord] {
        guard FileManager.default.fileExists(at: self.usageFilePath) else {
            return []
        }

        let fileHandle = try FileHandle(forReadingFrom: self.usageFilePath)

        let records = try await fileHandle.bytes.lines
            .compactMap(self.parseLine)
            .reduce(into: [VMUsageRecord]()) { $0.append($1) }

        try fileHandle.close()

        return records
    }

    @Sendable
    func parseLine(line: String) async -> VMUsageRecord? {
        let parts = line.components(separatedBy: CharacterSet(charactersIn: "\t"))

        guard
            let vm = parts.first,
            let timestamp = parts.last,
            let linestamp = self.dateFormatter.date(from: String(timestamp))
        else {
            return nil
        }

        return VMUsageRecord(vm: String(vm), date: linestamp)
    }
}
