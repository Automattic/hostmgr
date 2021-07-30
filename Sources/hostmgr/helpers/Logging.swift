import Logging

var logger = Logger(label: "com.automattic.hostmgr")

func initializeLoggingSystem() {
    logger.logLevel = .trace
    LoggingSystem.bootstrap { label in
        MultiplexLogHandler([
            StreamLogHandler.standardError(label: label)
        ])
    }
}
