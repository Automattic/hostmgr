import Foundation
import ArgumentParser

private let startDate = Date()

struct DiskBenchmark: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disk",
        abstract: "Test Disk Write"
    )

    func run() throws {
        let byteCount = 4096
        let bytes = Data([UInt8](repeating: 0, count: byteCount))
        let tempFile = try FileManager.default.createTemporaryFile()
        let file = try FileHandle(forWritingTo: tempFile)

        var totalBytesWritten: Int64 = 0

        while true {
            file.write(bytes)
            totalBytesWritten += Int64(byteCount)

            // Sample only one in 100 entries
            guard Int.random(in: 0...1000) == 0 else {
                continue
            }

            let writtenSize = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)

            let secondsElapsed = Date().timeIntervalSince(startDate)
            let perSecond = Double(totalBytesWritten) / Double(secondsElapsed)
            let rate = ByteCountFormatter.string(fromByteCount: Int64(perSecond), countStyle: .file)

            print("\(writtenSize) written  [Rate: \(rate) per second]")
        }
    }
}
