import Foundation

public struct FileTransferProgress {
    public typealias Percentage = Decimal

    let completed: Int
    let total: Int
    private let startDate = Date()

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }

    public var percent: Percentage {
        Decimal(Double(self.completed) / Double(self.total) * 100.0)
    }

    public var downloadedData: String {
        ByteCountFormatter.string(fromByteCount: Int64(self.completed), countStyle: .file)
    }

    public var totalData: String {
        ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    public var dataRate: Double {
        let elapsedTime = Date().timeIntervalSince(startDate)
        return Double(self.completed) / elapsedTime
    }

    public var estimatedTimeRemaining: TimeInterval {
        let elapsedTime = Date().timeIntervalSince(startDate)
        let bytesPerSecond = Double(self.completed) / elapsedTime

        // Don't continue unless the rate makes some kind of sense
        guard bytesPerSecond.isNormal else {
            return .infinity
        }

        let totalNumberOfSeconds = Double(total) / bytesPerSecond

        return totalNumberOfSeconds - elapsedTime
    }

    static func progressData(from progress: Progress) -> FileTransferProgress {
        return FileTransferProgress(
            completed: Int(progress.completedUnitCount),
            total: Int(progress.totalUnitCount)
        )
    }
}
