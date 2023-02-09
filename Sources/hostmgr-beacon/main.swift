import Cocoa
import libhostmgr

if #available(macOS 13.0, *) {
    let server = try! RPCServer()
    server.start()
} else {
    // Fallback on earlier versions
}

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

