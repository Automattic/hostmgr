import Foundation

public struct FileTransferProgress {
    public typealias Percentage = Decimal

    let current: Int
    let total: Int

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var percent: Percentage {
        Decimal(Double(self.current) / Double(self.total) * 100.0)
    }

    public var downloadedData: String {
        ByteCountFormatter.string(fromByteCount: Int64(current), countStyle: .file)
    }

    public var totalData: String {
        ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    public func dataRate(timeIntervalSinceStart interval: TimeInterval) -> String {
        let bytesPerSecond = Double(current) / interval

        // Don't continue unless the rate can be represented by `Int64`
        guard bytesPerSecond.isNormal else {
            return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
        }

        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
    }

    public func estimatedTimeRemaining(timeIntervalSinceStart interval: TimeInterval) -> TimeInterval {
        let bytesPerSecond = Double(current) / interval

        // Don't continue unless the rate makes some kind of sense
        guard bytesPerSecond.isNormal else {
            return .infinity
        }

        let totalNumberOfSeconds = Double(total) / bytesPerSecond

        return totalNumberOfSeconds - interval
    }

    public var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.alwaysShowsDecimalSeparator = true
        formatter.roundingMode = .down
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: percent as NSDecimalNumber)!
    }

    static func progressData(from progress: Progress) -> FileTransferProgress {
        return FileTransferProgress(
            current: Int(progress.completedUnitCount),
            total: Int(progress.totalUnitCount)
        )
    }
}
