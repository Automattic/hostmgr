import XCTest
@testable import libhostmgr

struct TestCommand: FollowsCommandPolicies {
    static var commandIdentifier = "TestCommandIdentifier"
    static var commandPolicies: [CommandPolicy] = []
}

class CommandPolicyTests: XCTestCase {

    private let stateRepository = InMemoryStateRepository()
    private let testKey = "foo"

    override func setUpWithError() throws {

    }

    override func tearDownWithError() throws {
        try stateRepository.deleteAll()
    }

    // MARK: Evaluation
    func testThatEvaluationIsPerformedWhenPredicateIsFalseForUnlessStatement() throws {
        var value = false
        to({ value = true }(), unless: false)
        XCTAssertTrue(value)
    }

    func testThatEvaluationIsNotPerformedWhenPredicateIsFalseForUnlessStatement() throws {
        var value = false
        to({ value = true }(), unless: true)
        XCTAssertFalse(value)
    }

    func testThatEvaluationIsPerformedWhenPredicateIsTrueForIfStatement() throws {
        var value = false
        to({ value = true }(), if: true)
        XCTAssertTrue(value)
    }

    func testThatEvaluationIsNotPerformedWhenPredicateIsFalseForIfStatement() throws {
        var value = false
        to({ value = true }(), if: false)
        XCTAssertFalse(value)
    }

    // MARK: Schedule Tests
    func testThatScheduleDoesNotThrowForFirstRun() throws {
        try CommandPolicy.scheduled(every: 30).evaluate(forKey: #function, stateRepository: stateRepository)
    }

    func testThatScheduleDoesNotThrowWhenTimeToRun() throws {
        try setLastRun(to: Date().addingTimeInterval(-45), forKey: #function)
        try CommandPolicy.scheduled(every: 30).evaluate(forKey: #function, stateRepository: stateRepository)
    }

    func testThatScheduleDoesNotThrowForDistantPast() throws {
        try setLastRun(to: .distantPast, forKey: #function)
        try CommandPolicy.scheduled(every: 30).evaluate(forKey: #function, stateRepository: stateRepository)
    }

    func testThatScheduleThrowsForNotTimeYet() throws {
        try setLastRun(to: Date(), forKey: #function)

        let policy = CommandPolicy.scheduled(every: 3600)

        XCTAssertThrowsError(try policy.evaluate(
            forKey: #function,
            stateRepository: stateRepository)
        ) { error in
            XCTAssertTrue(error is CommandPolicyViolation)
        }
    }

    // MARK: Serial Execution Tests
    func testThatSerialExecutionDoesNotThrowForMissingLock() throws {
        try CommandPolicy.serialExecution.evaluate(forKey: #function, stateRepository: stateRepository)
    }

    func testThatSerialExecutionDoesNotThrowForExpiredLock() throws {
        try setLastHeartbeat(to: Date().addingTimeInterval(-61), forKey: #function)
        try CommandPolicy.serialExecution.evaluate(forKey: #function, stateRepository: stateRepository)
    }

    func testThatSerialExecutionThrowsForActiveLock() throws {
        try setLastHeartbeat(to: Date().addingTimeInterval(-59), forKey: #function)

        let policy = CommandPolicy.serialExecution
        XCTAssertThrowsError(try policy.evaluate(
            forKey: #function,
            stateRepository: stateRepository)
        ) { error in
            XCTAssertTrue(error is CommandPolicyViolation)
        }
    }

    // MARK: Helpers
    private func setLastRun(to date: Date, forKey key: String) throws {
        try stateRepository.write(CommandPolicy.ScheduledCommandState(lastRunAt: date), toKey: key)
    }

    private func setLastHeartbeat(to date: Date, forKey key: String) throws {
        try stateRepository.write(CommandPolicy.SerialExecutionState(heartbeat: date), toKey: key)
    }
}
