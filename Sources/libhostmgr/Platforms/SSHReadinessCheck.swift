import Foundation
import Network
import OSLog

/// Callbacks run on the queue passed to start(queue:).
protocol SSHReadinessConnection: AnyObject {
    var state: NWConnection.State { get }
    var stateUpdateHandler: (@Sendable (NWConnection.State) -> Void)? { get set }
    var isLocalNetworkDenied: Bool { get }
    func start(queue: DispatchQueue)
    func restart()
    func cancel()
}

extension NWConnection: SSHReadinessConnection {
    var isLocalNetworkDenied: Bool {
        currentPath?.unsatisfiedReason == .localNetworkDenied
    }
}

/// All state and connection operations are confined to queue.
final class SSHReadinessCheck: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.automattic.hostmgr.ssh-readiness")
    private let connection: SSHReadinessConnection
    private var continuation: CheckedContinuation<Void, Error>?
    private var deadlineTimer: DispatchSourceTimer?
    private var retryTimer: DispatchSourceTimer?
    private var lastWaitingError: NWError?
    private var cancelled = false

    private init(connection: SSHReadinessConnection) {
        self.connection = connection
    }

    static func wait(
        connection: SSHReadinessConnection,
        timeout: Duration,
        retryInterval: TimeInterval = 1
    ) async throws {
        let check = SSHReadinessCheck(connection: connection)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                check.queue.async {
                    check.start(continuation: continuation, timeout: timeout, retryInterval: retryInterval)
                }
            }
        } onCancel: {
            check.queue.async {
                check.cancelled = true
                check.finish(.failure(CancellationError()))
            }
        }
    }

    private func start(
        continuation: CheckedContinuation<Void, Error>,
        timeout: Duration,
        retryInterval: TimeInterval
    ) {
        self.continuation = continuation
        guard !cancelled else {
            finish(.failure(CancellationError()))
            return
        }

        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }

        let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
        let deadlineTimer = DispatchSource.makeTimerSource(queue: queue)
        deadlineTimer.schedule(deadline: .now() + max(0, seconds))
        deadlineTimer.setEventHandler { [weak self] in
            self?.timedOut()
        }
        self.deadlineTimer = deadlineTimer
        deadlineTimer.resume()

        // Refusals need retries without a path change. Leave denied connections waiting:
        // permission grants retry them automatically, and a restart could hide the denial.
        let retryTimer = DispatchSource.makeTimerSource(queue: queue)
        retryTimer.schedule(deadline: .now() + retryInterval, repeating: retryInterval)
        retryTimer.setEventHandler { [weak self] in
            guard let self, self.continuation != nil, case .waiting = self.connection.state,
                  !self.connection.isLocalNetworkDenied else { return }
            self.connection.restart()
        }
        self.retryTimer = retryTimer
        retryTimer.resume()

        connection.start(queue: queue)
    }

    private func handle(_ state: NWConnection.State) {
        guard continuation != nil else { return }
        switch state {
        case .ready:
            finish(.success(()))
        case .waiting(let error):
            lastWaitingError = error
            Logger.lib.debug("Waiting for VM SSH: \(error), localNetworkDenied: \(connection.isLocalNetworkDenied)")
        case .failed(let error):
            finish(.failure(error))
        case .cancelled:
            finish(.failure(CancellationError()))
        default:
            break
        }
    }

    private func timedOut() {
        // The current path reflects permission changes during the wait.
        if connection.isLocalNetworkDenied {
            finish(.failure(HostmgrError.sshLocalNetworkAccessDenied))
        } else if let lastWaitingError {
            finish(.failure(HostmgrError.sshAvailabilityTimeoutWithError(String(describing: lastWaitingError))))
        } else {
            finish(.failure(HostmgrError.sshAvailabilityTimeout))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        deadlineTimer?.cancel()
        deadlineTimer = nil
        retryTimer?.cancel()
        retryTimer = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume(with: result)
    }
}
