import Foundation
import ArgumentParser
import libhostmgr

struct VMStartCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Starts a VM"
    )

    @Argument
    var name: String

    @Flag(help: "Wait for the machine to finish starting up?")
    var wait: Bool = false

    @Flag(help: "Mount the system git mirrors directory into the virtual machine on startup?")
    var withGitMirrors: Bool = false

    private let startTime = Date()

    enum CodingKeys: CodingKey {
        case name
        case wait
        case withGitMirrors
    }

    func run() async throws {
        let configuration = try LaunchConfiguration(name: self.name, sharedPaths: self.sharedPaths)
        try await libhostmgr.startVM(withLaunchConfiguration: configuration)

        guard wait else {
            return
        }

        #if arch(arm64)
        try await arm64Start()
        #endif
    }

    #if arch(arm64)
    func arm64Start() async throws {
        guard let tempFilePath = try LocalVMRepository().lookupVM(withName: name)?.path else {
            Console.crash(message: "There is no local VM called `\(name)`", reason: .fileNotFound)
        }

        guard let ipAddress = try VMBundle.fromExistingBundle(at: tempFilePath).currentDHCPLease?.ipAddress else {
            Console.crash(
                message: "Couldn't find an IP address for `\(name)` – is it running?",
                reason: .invalidVMStatus
            )
        }

        Console.info("Waiting for SSH server to become available")
        try await VMLauncher.waitForSSHServer(forAddress: ipAddress)
        Console.success("SSH server is available")

        Console.success("Startup Complete – Elapsed time: \(Format.elapsedTime(between: startTime, and: .now))")
        Console.info("You can access the VM using `ssh builder@\(ipAddress)`")
    }
    #endif

    var sharedPaths: [LaunchConfiguration.SharedPath] {
        get throws {
            guard try FileManager.default.directoryExists(at: Paths.gitMirrorStorageDirectory) else {
                return []
            }

            return [
                LaunchConfiguration.SharedPath(source: Paths.gitMirrorStorageDirectory, readOnly: true)
            ]
        }
    }
}
