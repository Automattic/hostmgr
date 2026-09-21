import XCTest
import Network
@testable import libhostmgr

final class SSHReadinessCheckTests: XCTestCase {
    func testConnectsWhenListenerStartsAfterRefusal() async throws {
        let listener = try DeferredTCPListener()
        defer { listener.close() }
        let refused = expectation(description: "Initial connection was refused")
        let connection = ObservedSSHConnection(port: listener.port) { error in
            XCTAssertEqual(error, .posix(.ECONNREFUSED))
            refused.fulfill()
            XCTAssertEqual(listener.listen(), 0)
        }

        try await SSHReadinessCheck.wait(connection: connection, timeout: .seconds(3), retryInterval: 0.05)

        await fulfillment(of: [refused], timeout: 1)
        XCTAssertNil(connection.stateUpdateHandler)
        XCTAssertNil(connection.connection.stateUpdateHandler)
    }

    func testSuccessIgnoresLateCallbacksAndDeadline() async throws {
        let connection = StubSSHConnection(state: .ready)
        connection.onStart = { connection in
            // Queued callbacks retain the handler even after cleanup.
            connection.emit(.failed(.posix(.ECONNRESET)))
            connection.emit(.cancelled)
        }

        try await SSHReadinessCheck.wait(connection: connection, timeout: .milliseconds(80), retryInterval: 0.01)
        assertCleanedUp(connection)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(connection.cancelCount, 1)
        XCTAssertEqual(connection.restartCount, 0)
    }

    func testPreparingConnectionWaitsForFractionalDeadline() async {
        let connection = StubSSHConnection(state: .preparing)
        let start = ContinuousClock.now
        let error = await failure(connection, timeout: .milliseconds(100))

        guard case HostmgrError.sshAvailabilityTimeout = error else {
            return XCTFail("Expected timeout, got \(error)")
        }
        XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(80))
        XCTAssertLessThan(start.duration(to: .now), .seconds(2))
        XCTAssertEqual(connection.restartCount, 0)
        assertCleanedUp(connection)
    }

    func testRetriesPreserveDeadlineAndLatestError() async {
        let connection = StubSSHConnection(state: .waiting(.posix(.ECONNREFUSED)))
        // A permission errno alone must not be diagnosed as Local Network denial.
        connection.onRestart = { $0.emit(.waiting(.posix(.EACCES))) }
        let start = ContinuousClock.now
        let error = await failure(connection, timeout: .milliseconds(100))

        guard case HostmgrError.sshAvailabilityTimeoutWithError(let details) = error else {
            return XCTFail("Expected timeout with waiting error, got \(error)")
        }
        XCTAssertEqual(details, String(describing: NWError.posix(.EACCES)))
        XCTAssertGreaterThan(connection.restartCount, 0)
        XCTAssertLessThan(start.duration(to: .now), .seconds(2))
        assertCleanedUp(connection)
    }

    func testPropagatesTerminalFailure() async {
        let connection = StubSSHConnection(state: .failed(.posix(.ECONNRESET)))
        let error = await failure(connection, timeout: .seconds(5))

        XCTAssertEqual(error as? NWError, .posix(.ECONNRESET))
        XCTAssertEqual(connection.restartCount, 0)
        assertCleanedUp(connection)
    }

    func testCancellationBeforeStart() async {
        let connection = StubSSHConnection(state: .waiting(.posix(.ECONNREFUSED)))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await self.failure(connection, timeout: .seconds(5))
        }
        let error = await task.value

        XCTAssertTrue(error is CancellationError)
        XCTAssertEqual(connection.startCount, 0)
        XCTAssertEqual(connection.restartCount, 0)
        assertCleanedUp(connection)
    }

    func testCancellationWhileWaiting() async {
        let started = expectation(description: "Connection started")
        let connection = StubSSHConnection(state: .waiting(.posix(.ECONNREFUSED)))
        connection.onStart = { _ in started.fulfill() }
        let task = Task { await self.failure(connection, timeout: .seconds(5)) }
        await fulfillment(of: [started], timeout: 1)

        let start = ContinuousClock.now
        task.cancel()
        let error = await task.value

        XCTAssertTrue(error is CancellationError)
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))
        assertCleanedUp(connection)
    }

    func testPermissionDenialWaitsForDeadline() async {
        let connection = StubSSHConnection(state: .waiting(.posix(.EACCES)), denied: true)
        let start = ContinuousClock.now
        let error = await failure(connection, timeout: .milliseconds(100))

        guard case HostmgrError.sshLocalNetworkAccessDenied = error else {
            return XCTFail("Expected Local Network denial, got \(error)")
        }
        XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(80))
        XCTAssertEqual(connection.restartCount, 0)
        assertCleanedUp(connection)
    }

    func testPermissionGrantAllowsConnection() async throws {
        let connection = StubSSHConnection(state: .waiting(.posix(.EACCES)), denied: true)
        connection.onStart = { connection in
            connection.performAfter(0.03) {
                connection.isLocalNetworkDenied = false
                connection.emit(.ready)
            }
        }

        try await SSHReadinessCheck.wait(connection: connection, timeout: .seconds(1), retryInterval: 0.01)

        XCTAssertEqual(connection.restartCount, 0)
        assertCleanedUp(connection)
    }

    func testClearedDenialReportsConnectionError() async {
        let connection = StubSSHConnection(state: .waiting(.posix(.EACCES)), denied: true)
        connection.onStart = { connection in
            connection.performAfter(0.03) {
                connection.isLocalNetworkDenied = false
                connection.emit(.waiting(.posix(.ECONNREFUSED)))
            }
        }
        let error = await failure(connection, timeout: .milliseconds(100))

        guard case HostmgrError.sshAvailabilityTimeoutWithError(let details) = error else {
            return XCTFail("Expected ordinary timeout after permission recovered, got \(error)")
        }
        XCTAssertEqual(details, String(describing: NWError.posix(.ECONNREFUSED)))
        assertCleanedUp(connection)
    }

    private func failure(_ connection: StubSSHConnection, timeout: Duration) async -> Error {
        do {
            try await SSHReadinessCheck.wait(connection: connection, timeout: timeout, retryInterval: 0.01)
            XCTFail("Expected the readiness check to fail")
            return UnexpectedSuccess()
        } catch {
            return error
        }
    }

    private func assertCleanedUp(_ connection: StubSSHConnection, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(connection.cancelCount, 1, file: file, line: line)
        XCTAssertNil(connection.stateUpdateHandler, file: file, line: line)
    }

    private struct UnexpectedSuccess: Error {}
}
