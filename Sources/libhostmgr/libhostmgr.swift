import Foundation
import OSLog

public let hostmgrVersion = "0.50.2"

public extension Logger {
    private static let subsystem = "com.automattic.hostmgr"

    static let cli    = AlwaysLogToConsoleMiddleware(logger: Logger(subsystem: subsystem, category: "cli"))
    static let lib    = AlwaysLogToConsoleMiddleware(logger: Logger(subsystem: subsystem, category: "lib"))
    static let helper = AlwaysLogToConsoleMiddleware(logger: Logger(subsystem: subsystem, category: "helper"))
}

public protocol LoggingMiddleware {
    var logger: Logger { get }
    var useVerboseLogging: Bool { get }
}

extension LoggingMiddleware {
    public func log(_ message: String, level: OSLogType = .default) {
        var mutableLevel = level

        // Treat everything like a fault to bypass the systems' logging settings
        if useVerboseLogging {
            mutableLevel = .fault
        }

        logger.log(level: mutableLevel, "\(message, privacy: .public)")
    }

    public func debug(_ message: String) {
        log(message, level: .debug)
    }

    public func error(_ message: String) {
        log(message, level: .error)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func warning(_ message: String) {
        log(message, level: .fault)
    }
}

public struct AlwaysLogToConsoleMiddleware: LoggingMiddleware {
    public let logger: Logger
    public var useVerboseLogging: Bool = true
}
