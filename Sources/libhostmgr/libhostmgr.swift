import Foundation
import OSLog

public extension Logger {
    static let lib    = Logger(subsystem: "com.automattic.hostmgr", category: "lib")
    static let helper = Logger(subsystem: "com.automattic.hostmgr.helper", category: "main")
}
