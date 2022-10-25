import Foundation

public class Limiter {
    public enum Policy {
        case throttle
        case debounce
    }

    private let policy: Policy
    private let operationsPerSecond: TimeInterval
    private var task: Task<Void, Error>?

    /// Non-async/await tracking
    private var previousRun = Date.distantPast
    private let queue = DispatchQueue(label: "limiter-dispatch-queue", qos: .utility)
    private var job = DispatchWorkItem(block: {})

    public init(policy: Policy, operationsPerSecond: TimeInterval) {
        self.policy = policy
        self.operationsPerSecond = operationsPerSecond
    }

    public func perform(operation: @escaping () async -> Void) {
        switch policy {
        case .throttle: throttle(operation: operation)
        case .debounce: debounce(operation: operation)
        }
    }

    public func perform(operation: @escaping () -> Void) {
        switch policy {
        case .throttle: throttle(block: operation)
        case .debounce: throttle(block: operation)
        }
    }

    /// The `operation` will be called the very first time this function is called, and, at most, once per specified
    /// period.
    private func throttle(operation: @escaping () async -> Void) {
        guard task == nil else { return }

        task = Task {
            try? await sleep()
            task = nil
        }

        Task {
            await operation()
        }
    }

    /// The `block` will be called the very first time this function is called, and, at most, once per specified period.
    private func throttle(block: @escaping () -> Void) {
        configureJob(block: block)

        let delay = Date().timeIntervalSince(previousRun) > operationsPerSecond ? 0 : operationsPerSecond
        queue.asyncAfter(deadline: .now() + Double(delay), execute: job)
    }

    /// The original function will be called once this method hasn't been run for the specified period.
    private func debounce(block: @escaping () -> Void) {
        configureJob(block: block)
        queue.asyncAfter(deadline: .now() + operationsPerSecond, execute: job)
    }

    private func configureJob(block: @escaping () -> Void) {
        job.cancel()
        job = DispatchWorkItem { [weak self] in
            self?.previousRun = Date()
            self?.queue.async { block() }
        }
    }

    /// The original function will be called once this method hasn't been run for the specified period.
    private func debounce(operation: @escaping () async -> Void) {
        task?.cancel()

        task = Task {
            try await sleep()
            await operation()
            task = nil
        }
    }

    private func sleep() async throws {
        try await Task.sleep(nanoseconds: UInt64(operationsPerSecond * .nanosecondsPerSecond))
    }
}

// MARK: - TimeInterval
extension TimeInterval {
    static let nanosecondsPerSecond = TimeInterval(NSEC_PER_SEC)
}
