import Foundation
import Logging

var logger = Logger(label: "com.automattic.hostmgr")

func initializeLoggingSystem() {
    let logLevelFromEnv = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap { Logger.Level(rawValue: $0) }
    logger.logLevel = logLevelFromEnv ?? .info
    LoggingSystem.bootstrap { label in
        MultiplexLogHandler([
            StreamLogHandler.standardError(label: label)
        ])
    }
}
