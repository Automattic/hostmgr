import Foundation
import CryptoKit
import Virtualization

public enum ProcessorArchitecture: String {
    case arm64
    case x64 = "x86_64"
}

extension ProcessInfo {

    /// How many cores are in this machine?
    ///
    /// On Apple Silicon, this returns the number of Performance Cores + Efficiency Cores
    ///
    /// On Intel, this returns the number of "real" cores (excluding hyperthreading "cores")
    ///
    public var physicalProcessorCount: Int {
        var size: size_t = MemoryLayout<Int>.size
        var coresCount: Int = 0
        sysctlbyname("hw.physicalcpu", &coresCount, &size, nil, 0)
        return coresCount
    }
}

extension Date {
    /// Required until we only support macOS 12
    static var now: Date {
        return Date()
    }
}

extension String {
    public var trimmingWhitespace: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { lhs, rhs in
            return lhs[keyPath: keyPath] < rhs[keyPath: keyPath]
        }
    }
}

extension String {

    public func slugify() -> String {
        self.components(separatedBy: .alphanumerics.inverted).joined(separator: "-")
    }
}

extension Progress {
    func estimateThroughput(fromTimeElapsed elapsedTime: TimeInterval) {
        guard Int64(elapsedTime) > 0 else {
            self.setUserInfoObject(0, forKey: .throughputKey)
            self.setUserInfoObject(TimeInterval.infinity, forKey: .estimatedTimeRemainingKey)
            return
        }

        let unitsPerSecond = self.completedUnitCount.quotientAndRemainder(dividingBy: Int64(elapsedTime)).quotient
        let throughput = Int(unitsPerSecond)
        self.setUserInfoObject(throughput, forKey: .throughputKey)

        guard throughput > 0 else {
            self.setUserInfoObject(TimeInterval.infinity, forKey: .estimatedTimeRemainingKey)
            return
        }

        let unitsRemaining = self.totalUnitCount - self.completedUnitCount
        let secondsRemaining = unitsRemaining.quotientAndRemainder(dividingBy: Int64(throughput)).quotient

        self.setUserInfoObject(TimeInterval(secondsRemaining), forKey: .estimatedTimeRemainingKey)
    }
}

public func to(_ callback: @autoclosure () throws -> Void, if conditional: Bool) rethrows {
    guard conditional == true else {
        return
    }

    try callback()
}

public func to(_ callback: @autoclosure () throws -> Void, unless conditional: Bool) rethrows {
    guard conditional == false else {
        return
    }

    try callback()
}

public typealias ProgressCallback = (Progress) -> Void

extension Task where Failure == Error {
    @discardableResult
    public static func retrying(
        times: Int = 3,
        delay: TimeInterval = 1,
        operation: @Sendable @escaping () async throws -> Success
    ) -> Task {
        Task {
            for _ in 0..<times {
                do {
                    return try await operation()
                } catch {
                    try await Task<Never, Never>.sleep(for: .seconds(delay))
                    continue
                }
            }

            try Task<Never, Never>.checkCancellation()
            return try await operation()
        }
    }
}
