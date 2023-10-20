import Foundation

actor VMUsageTracker {

    private let usageFilePath: URL
    private let dateFormatter = ISO8601DateFormatter()

    init(usageFilePath: URL = Paths.vmUsageFile) {
        self.usageFilePath = usageFilePath
    }

    func trackUsageOf(vmNamed name: String, on date: Date = Date()) throws {
        try createUsageFileIfNotExists()

        let fileHandle = try FileHandle(forWritingTo: self.usageFilePath)
        try fileHandle.seekToEnd()

        let line = name + "\t" + self.dateFormatter.string(from: date) + "\n"
        try fileHandle.write(contentsOf: Data(line.utf8))

        try fileHandle.close()
    }

    func usageCountFor(vmNamed name: String, since date: Date) async throws -> Int {
        try createUsageFileIfNotExists()

        let fileHandle = try FileHandle(forReadingFrom: self.usageFilePath)

        var count = 0

        for try await line in fileHandle.bytes.lines {
            guard line.hasPrefix(name), let usageRecord = await parseLine(line: line) else {
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
        try createUsageFileIfNotExists()

        let fileHandle = try FileHandle(forReadingFrom: self.usageFilePath)

        let records = try await fileHandle.bytes.lines
            .compactMap(self.parseLine)
            .reduce(into: [VMUsageRecord]()) { $0.append($1) }

        try fileHandle.close()

        return records
    }

    func createUsageFileIfNotExists() throws {
        let parentDirectory = usageFilePath.deletingLastPathComponent()

        if try !FileManager.default.directoryExists(at: parentDirectory) {
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        }

        if !FileManager.default.fileExists(at: usageFilePath) {
            try FileManager.default.createFile(at: usageFilePath, contents: Data())
        }
    }

    @Sendable
    func parseLine(line: String) async -> VMUsageRecord? {
        let parts = line.components(separatedBy: CharacterSet(charactersIn: "\t"))

        guard
            let vmName = parts.first,
            let timestamp = parts.last,
            let linestamp = self.dateFormatter.date(from: String(timestamp))
        else {
            return nil
        }

        return VMUsageRecord(vmName: String(vmName), date: linestamp)
    }
}
