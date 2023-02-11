import Foundation
import Logging

// swiftlint:disable type_name
/// A hack to allow global logging
struct logger {
    static func debug(_ message: @autoclosure () -> Logger.Message) {
        Logger.shared.debug(message())
    }

    static func trace(_ message: @autoclosure () -> Logger.Message) {
        Logger.shared.trace(message())
    }

    static func error(_ message: @autoclosure () -> Logger.Message) {
        Logger.shared.error(message())
    }

    static func info(_ message: @autoclosure () -> Logger.Message) {
        Logger.shared.info(message())
    }
}
// swiftlint:enable type_name

extension Logger {
    static var shared = Logger(label: "com.automattic.hostmgr")

    static func initializeLoggingSystem() {

        #if DEBUG
        Logger.shared.logLevel = .trace
        #else
        let logLevelFromEnv = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap { Logger.Level(rawValue: $0) }
        Logger.shared.logLevel = logLevelFromEnv ?? .info
        #endif

        LoggingSystem.bootstrap { label in
            MultiplexLogHandler([
                StreamLogHandler.standardError(label: label)
            ])
        }
    }
}
