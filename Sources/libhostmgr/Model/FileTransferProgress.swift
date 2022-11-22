import Foundation

public struct FileTransferProgress {
    typealias Percentage = Decimal

    private let completed: Int
    private let total: Int
    private let startDate: Date

    init(completed: Int, total: Int, startDate: Date) {
        self.completed = completed
        self.total = total
        self.startDate = startDate
    }

    var fractionComplete: Percentage {
        Decimal(Double(self.completed) / Double(self.total))
    }

    var dataRate: Double {
        return Double(self.completed) / Date().timeIntervalSince(startDate)
    }

    var estimatedTimeRemaining: TimeInterval {
        let elapsedTime = Date().timeIntervalSince(startDate)
        let bytesPerSecond = Double(self.completed) / elapsedTime

        // Don't continue unless the rate makes some kind of sense
        guard bytesPerSecond.isNormal else {
            return .infinity
        }

        let totalNumberOfSeconds = Double(total) / bytesPerSecond

        return totalNumberOfSeconds - elapsedTime
    }

    var percent: Percentage {
        Decimal(Double(self.completed) / Double(self.total) * 100.0)
    }

    var downloadedData: String {
        ByteCountFormatter.string(fromByteCount: Int64(self.completed), countStyle: .file)
    }

    var totalData: String {
        ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    func dataRate(timeIntervalSinceStart interval: TimeInterval) -> String {
        let bytesPerSecond = Double(self.completed) / interval

        // Don't continue unless the rate can be represented by `Int64`
        guard bytesPerSecond.isNormal else {
            return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
        }

        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
    }

    func estimatedTimeRemaining(timeIntervalSinceStart interval: TimeInterval) -> TimeInterval {
        let bytesPerSecond = Double(self.completed) / interval

        // Don't continue unless the rate makes some kind of sense
        guard bytesPerSecond.isNormal else {
            return .infinity
        }

        let totalNumberOfSeconds = Double(total) / bytesPerSecond

        return totalNumberOfSeconds - interval
    }

    var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.alwaysShowsDecimalSeparator = true
        formatter.roundingMode = .down
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: percent as NSDecimalNumber)!
    }

    static func progressData(from progress: Progress, withStartDate date: Date) -> FileTransferProgress {
        return FileTransferProgress(
            completed: Int(progress.completedUnitCount),
            total: Int(progress.totalUnitCount),
            startDate: date
        )
    }
}
