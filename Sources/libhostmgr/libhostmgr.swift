import Foundation
import OSLog

public let hostmgrVersion = "0.50.0-beta.7"

public extension Logger {
    static let lib    = Logger(subsystem: "com.automattic.hostmgr", category: "lib")
    static let helper = Logger(subsystem: "com.automattic.hostmgr.helper", category: "main")
}
