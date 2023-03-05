import Foundation
import ArgumentParser
import libhostmgr

struct InstallHostmgrHelperCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "helper",
        abstract: "Install the `hostmgr-helper` tool"
    )

    private let agentIdentifier = "com.automattic.hostmgr.helper"
    private let helperPath = URL(fileURLWithPath: ProcessInfo.processInfo.arguments.first!)
        .deletingLastPathComponent()
        .appendingPathComponent("hostmgr-helper").path

    private let stdoutPath = Paths.logsDirectory.appendingPathComponent("hostmgr-helper.stdout.log").path
    private let stderrPath = Paths.logsDirectory.appendingPathExtension("hostmgr-helper.stderr.log").path

    enum CodingKeys: CodingKey {}

    func run() throws {
        guard FileManager.default.fileExists(atPath: helperPath) else {
            Console.crash(
                message: "`hostmgr-helper` is missing – please reinstall `hostmgr` (should be at \(helperPath))",
                reason: .fileNotFound
            )
        }

       try agentTemplate
            .replacingOccurrences(of: "${AGENT_IDENTIFIER}", with: agentIdentifier)
            .replacingOccurrences(of: "${APPLICATION_PATH}", with: helperPath)
            .replacingOccurrences(of: "${STDOUT_PATH}", with: stdoutPath)
            .replacingOccurrences(of: "${STDERR_PATH}", with: stderrPath)
            .write(to: plistDesination, atomically: true, encoding: .utf8)
    }

    private var plistDesination: URL {
        Paths.userLaunchAgentsDirectory
           .appendingPathComponent(agentIdentifier)
           .appendingPathExtension("plist")
    }

    private let agentTemplate = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>MachServices</key>
    <dict>
        <key>com.hostmgr.helper.xpc</key>
        <true/>
    </dict>

    <key>Label</key>
    <string>${AGENT_IDENTIFIER}</string>

    <key>Program</key>
    <string>${APPLICATION_PATH}</string>

    <key>KeepAlive</key>
    <true/>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${STDOUT_PATH}</string>

    <key>StandardErrorPath</key>
    <string>${STDERR_PATH}</string>
</dict>
</plist>

"""
}
