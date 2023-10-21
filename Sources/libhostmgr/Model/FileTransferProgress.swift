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
}
