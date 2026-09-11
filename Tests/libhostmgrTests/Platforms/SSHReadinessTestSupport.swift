import Foundation
import Network
import Darwin
@testable import libhostmgr

/// Shared state is locked; callbacks run on the readiness queue.
final class StubSSHConnection: SSHReadinessConnection, @unchecked Sendable {
    private let lock = NSLock()
    private var callbackQueue: DispatchQueue?
    private var handler: (@Sendable (NWConnection.State) -> Void)?
    private var currentState: NWConnection.State
    private var denied: Bool
    private var starts = 0
    private var restarts = 0
    private var cancels = 0

    // Configure before starting the check.
    var onStart: ((StubSSHConnection) -> Void)?
    var onRestart: ((StubSSHConnection) -> Void)?

    init(state: NWConnection.State, denied: Bool = false) {
        currentState = state
        self.denied = denied
    }

    var state: NWConnection.State { lock.withLock { currentState } }
    var startCount: Int { lock.withLock { starts } }
    var restartCount: Int { lock.withLock { restarts } }
    var cancelCount: Int { lock.withLock { cancels } }

    var stateUpdateHandler: (@Sendable (NWConnection.State) -> Void)? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    var isLocalNetworkDenied: Bool {
        get { lock.withLock { denied } }
        set { lock.withLock { denied = newValue } }
    }

    func start(queue: DispatchQueue) {
        lock.withLock {
            callbackQueue = queue
            starts += 1
        }
        emit(state)
        onStart?(self)
    }

    func restart() {
        lock.withLock { restarts += 1 }
        onRestart?(self)
    }

    func cancel() {
        lock.withLock { cancels += 1 }
        emit(.cancelled)
    }

    /// Serialize path and state changes with readiness timers.
    func performAfter(_ delay: TimeInterval, _ update: @escaping @Sendable () -> Void) {
        let queue = lock.withLock { callbackQueue }
        queue?.asyncAfter(deadline: .now() + delay, execute: update)
    }

    func emit(_ state: NWConnection.State) {
        let (queue, callback) = lock.withLock {
            currentState = state
            return (callbackQueue, handler)
        }
        queue?.async { callback?(state) }
    }
}

/// Observes the first refusal before starting the listener.
final class ObservedSSHConnection: SSHReadinessConnection {
    let connection: NWConnection
    private let onFirstWaiting: (NWError) -> Void
    private var observedWaiting = false

    init(port: UInt16, onFirstWaiting: @escaping (NWError) -> Void) {
        connection = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        self.onFirstWaiting = onFirstWaiting
    }

    var state: NWConnection.State { connection.state }
    var isLocalNetworkDenied: Bool { connection.isLocalNetworkDenied }
    var stateUpdateHandler: (@Sendable (NWConnection.State) -> Void)? {
        didSet {
            guard let stateUpdateHandler else {
                connection.stateUpdateHandler = nil
                return
            }
            connection.stateUpdateHandler = { [weak self] state in
                if let self, case .waiting(let error) = state, !self.observedWaiting {
                    self.observedWaiting = true
                    self.onFirstWaiting(error)
                }
                stateUpdateHandler(state)
            }
        }
    }

    func start(queue: DispatchQueue) { connection.start(queue: queue) }
    func restart() { connection.restart() }
    func cancel() { connection.cancel() }
}

/// Choose an unused loopback port, then release it so the first connection is refused.
final class DeferredTCPListener {
    private let descriptor: Int32
    let port: UInt16

    init() throws {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw SocketSetupError() }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                guard bind(descriptor, $0, length) == 0 else { return Int32(-1) }
                return getsockname(descriptor, $0, &length)
            }
        }
        guard result == 0 else {
            Darwin.close(descriptor)
            throw SocketSetupError()
        }
        port = UInt16(bigEndian: address.sin_port)
        Darwin.close(descriptor)
        self.descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard self.descriptor >= 0 else { throw SocketSetupError() }
    }

    func listen() -> Int32 {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        address.sin_port = port.bigEndian
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        // Fail if another process claimed the port.
        return result == 0 ? Darwin.listen(descriptor, 1) : result
    }
    func close() { Darwin.close(descriptor) }

    private struct SocketSetupError: Error {}
}
