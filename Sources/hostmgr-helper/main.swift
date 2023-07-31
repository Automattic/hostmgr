import Foundation
import Cocoa
import OSLog


Logger.helper.debug("Helper is starting up")
Logger.helper.info("Creating App Delegate")

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

Logger.helper.debug("Starting run loop")

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

extension Logger {
    static let helper = Logger(subsystem: "com.automattic.hostmgr.helper", category: "main")
}
