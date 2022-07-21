import XCTest
@testable import libhostmgr

class CommandPolicyTests: XCTestCase {

    private let stateStorageManager = InMemoryStorageManager()
    private let testKey = "foo"

    override func setUpWithError() throws {

    }

    override func tearDownWithError() throws {
        try stateStorageManager.deleteAll()
    }

    // MARK: Schedule Tests
    func testThatScheduleDoesNotThrowForFirstRun() throws {
        try CommandPolicy.scheduled(every: 30).evaluate(forKey: #function, stateStorageManager: stateStorageManager)
    }

    func testThatScheduleDoesNotThrowWhenTimeToRun() throws {
        try setLastRun(to: Date().addingTimeInterval(-45), forKey: #function)
        try CommandPolicy.scheduled(every: 30).evaluate(forKey: #function, stateStorageManager: stateStorageManager)
    }

    func testThatScheduleDoesNotThrowForDistantPast() throws {
        try setLastRun(to: .distantPast, forKey: #function)
        try CommandPolicy.scheduled(every: 30).evaluate(forKey: #function, stateStorageManager: stateStorageManager)
    }

    func testThatScheduleThrowsForNotTimeYet() throws {
        try setLastRun(to: Date(), forKey: #function)

        let policy = CommandPolicy.scheduled(every: 3600)

        XCTAssertThrowsError(try policy.evaluate(
            forKey: #function,
            stateStorageManager: stateStorageManager)
        ) { error in
            XCTAssertTrue(error is CommandPolicyViolation)
        }
    }

    // MARK: Serial Execution Tests
    func testThatSerialExecutionDoesNotThrowForMissingLock() throws {
        try CommandPolicy.serialExecution.evaluate(forKey: #function, stateStorageManager: stateStorageManager)
    }

    func testThatSerialExecutionDoesNotThrowForExpiredLock() throws {
        try setLastHeartbeat(to: Date().addingTimeInterval(-61), forKey: #function)
        try CommandPolicy.serialExecution.evaluate(forKey: #function, stateStorageManager: stateStorageManager)
    }

    func testThatSerialExecutionThrowsForActiveLock() throws {
        try setLastHeartbeat(to: Date().addingTimeInterval(-59), forKey: #function)

        let policy = CommandPolicy.serialExecution
        XCTAssertThrowsError(try policy.evaluate(
            forKey: #function,
            stateStorageManager: stateStorageManager)
        ) { error in
            XCTAssertTrue(error is CommandPolicyViolation)
        }
    }

    // MARK: Helpers
    private func setLastRun(to date: Date, forKey key: String) throws {
        try stateStorageManager.write(CommandPolicy.ScheduledCommandState(lastRunAt: date), toKey: key)
    }

    private func setLastHeartbeat(to date: Date, forKey key: String) throws {
        try stateStorageManager.write(CommandPolicy.SerialExecutionState(heartbeat: date), toKey: key)
    }
}
