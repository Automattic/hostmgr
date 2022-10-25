import Foundation
import Logging

// swiftlint:disable type_name
/// A hack to allow global logging
struct logger {
    static func debug(_ message:  @autoclosure () -> Logger.Message) {
        Logger.shared.debug(message())
    }

    static func trace(_ message:  @autoclosure () -> Logger.Message) {
        Logger.shared.trace(message())
    }

    static func info(_ message:  @autoclosure () -> Logger.Message) {
        Logger.shared.info(message())
    }
}

extension Logger {
    static var shared = Logger(label: "com.automattic.hostmgr")

    static func initializeLoggingSystem() {
        #if DEBUG
        Logger.shared.logLevel = .trace
        #endif

        LoggingSystem.bootstrap { label in
            MultiplexLogHandler([
                StreamLogHandler.standardError(label: label)
            ])
        }
    }
}
