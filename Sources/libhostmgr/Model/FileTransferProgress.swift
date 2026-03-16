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
        guard total > 0 else { return 0 }
        return Decimal(Double(self.completed) / Double(self.total))
    }

    var dataRate: Double {
        let elapsed = Date().timeIntervalSince(startDate)
        guard elapsed > 0 else { return 0 }
        return Double(self.completed) / elapsed
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
}
