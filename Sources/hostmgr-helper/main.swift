import Foundation
import Cocoa
import Logging

print("Helper starting up")
var logger = Logger(label: "com.automattic.hostmgr.helper")
logger.logLevel = .trace

logger.info("Creating App Delegate")

let delegate = AppDelegate(logger: logger)
NSApplication.shared.delegate = delegate

logger.debug("Starting run loop")

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
