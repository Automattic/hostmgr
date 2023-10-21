import Foundation

public enum CommandPolicy: Equatable, Codable {
    /// Run according to a schedule defined by the provided `TimeInterval`.
    ///
    /// For instance, given a `TimeInterval` of `3600`, you could expect the command to be run
    /// no more frequently than every hour.
    case scheduled(every: TimeInterval)

    /// Run only one version of this process simultaneously (to the extent of the locking mechanism, anyway)
    case serialExecution

    /// Evaluate the policy, throwing an error if we're violating one
    internal func evaluate(forKey key: String, stateRepository: StateRepository) throws {
        switch self {
        case let .scheduled(timeInterval):
            try evaluateSchedule(
                forKey: key,
                timeInterval: timeInterval,
                stateRepository: stateRepository
            )
        case .serialExecution:
            try evaluateSerialQueueLock(
                forKey: key,
                stateRepository: stateRepository
            )
        }
    }

    var label: String {
        switch self {
        case .serialExecution: return "serial-execution"
        case .scheduled: return "schedule"
        }
    }

    private func evaluateSchedule(
        forKey key: String,
        timeInterval: TimeInterval,
        stateRepository: StateRepository
    ) throws {
        let state: ScheduledCommandState = try stateRepository.read(fromKey: key) ?? .default
        let nextRunTime = state.lastRunAt + timeInterval

        if nextRunTime > Date() {
            throw CommandPolicyViolation.notTimeYet(nextRunTime)
        }
    }

    private func evaluateSerialQueueLock(
        forKey key: String,
        stateRepository: StateRepository
    ) throws {
        let state: SerialExecutionState = try stateRepository.read(fromKey: key) ?? .default

        if state.heartbeat.timeIntervalSinceNow > -60 {
            throw CommandPolicyViolation.alreadyRunning
        }
    }

    struct ScheduledCommandState: Codable {
        var lastRunAt: Date = Date.distantPast

        static let `default` = Self(lastRunAt: Date.distantPast)
    }

    struct SerialExecutionState: Codable {
        var heartbeat: Date = Date()

        static let `default` = Self(heartbeat: Date.distantPast)
    }
}

internal enum CommandPolicyViolation: Error, CustomStringConvertible {
    case alreadyRunning
    case notTimeYet(Date)

    var description: String {
        switch self {
        case .alreadyRunning:
            return "Another instance of this process is already running"
        case let .notTimeYet(nextRunTime):
            return "This job is not scheduled to run until \(nextRunTime)"
        }
    }
}

public protocol FollowsCommandPolicies {
    /// A unique identifier for this command – used to derive a file storage path
    var commandIdentifier: String { get }

    /// The policies that apply to this command
    var commandPolicies: [CommandPolicy] { get }
}

public extension FollowsCommandPolicies {

    func key(forPolicy policy: CommandPolicy) -> String {
        commandIdentifier + "-" + policy.label
    }

    /// Evaluate any command policies on this command
    ///
    /// If any policies are violated (ie – it's not time to run yet), an error will be thrown
    /// that will cause the program to exit.
    func evaluateCommandPolicies(stateRepository: StateRepository? = nil) throws {
        let stateRepository = stateRepository ?? FileStateRepository()

        for policy in commandPolicies {
            try policy.evaluate(forKey: key(forPolicy: policy), stateRepository: stateRepository)
        }
    }

    /// Store a "heartbeat" time – the last time the job did work
    ///
    /// If it freezes, we'll use the last heartbeat time to decide whether to start up a new instance of the job.
    func recordHeartbeat(date: Date = Date(), stateRepository: StateRepository? = nil) throws {
        let stateRepository = stateRepository ?? FileStateRepository()

        var state = CommandPolicy.SerialExecutionState()
        state.heartbeat = date

        try stateRepository.write(state, toKey: key(forPolicy: .serialExecution))
    }

    /// Store the last run date for this job
    ///
    /// We'll use it to schedule the task to run periodically.
    func recordLastRun(date: Date = Date(), stateRepository: StateRepository? = nil) throws {
        let stateRepository = stateRepository ?? FileStateRepository()

        var state = CommandPolicy.ScheduledCommandState()
        state.lastRunAt = date

        try stateRepository.write(state, toKey: key(forPolicy: .scheduled(every: 0)))
    }
}
