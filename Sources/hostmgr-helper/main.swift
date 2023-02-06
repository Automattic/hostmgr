import Foundation
import Cocoa

if #available(macOS 13.0, *) {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate

    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
} else {
    abort()
}
