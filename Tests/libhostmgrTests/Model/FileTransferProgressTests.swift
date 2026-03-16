import XCTest
@testable import libhostmgr

final class FileTransferProgressTests: XCTestCase {

    func testFractionCompleteWithZeroTotal() {
        let progress = FileTransferProgress(completed: 0, total: 0, startDate: Date())
        XCTAssertEqual(progress.fractionComplete, 0)
        XCTAssertFalse(progress.fractionComplete.isNaN)
    }

    func testFractionCompleteWithNonZeroTotal() {
        let progress = FileTransferProgress(completed: 50, total: 100, startDate: Date())
        XCTAssertEqual(progress.fractionComplete, 0.5)
    }

    func testDataRateWithZeroElapsedTime() {
        let progress = FileTransferProgress(completed: 100, total: 200, startDate: Date())
        XCTAssertFalse(progress.dataRate.isNaN)
        XCTAssertFalse(progress.dataRate.isInfinite)
    }

    func testDataRateWithElapsedTime() {
        let progress = FileTransferProgress(completed: 1000, total: 2000, startDate: Date(timeIntervalSinceNow: -2))
        XCTAssertEqual(progress.dataRate, 500, accuracy: 50)
    }

    func testEstimatedTimeRemainingWithZeroCompleted() {
        let progress = FileTransferProgress(completed: 0, total: 100, startDate: Date())
        XCTAssertFalse(progress.estimatedTimeRemaining.isNaN)
    }

    func testEstimatedTimeRemainingWithZeroTotal() {
        let progress = FileTransferProgress(completed: 0, total: 0, startDate: Date())
        XCTAssertFalse(progress.estimatedTimeRemaining.isNaN)
    }
}
