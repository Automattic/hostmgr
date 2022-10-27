import Foundation
import Logging

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
