import Foundation
import ArgumentParser
import libhostmgr
import Network

struct VMStartCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Starts a VM"
    )

    @Argument
    var name: String

    @Option(help: "A handle that can be used to reference the VM later (useful for shutting down a specific VM)")
    var handle: String = UUID().uuidString

    @Flag(help: "Mount the system git mirrors directory into the virtual machine on startup?")
    var withGitMirrors: Bool = false

    @Flag(help: "Wait indefinitely for the SSH server to become available (useful when provisioning a new image")
    var waitForever: Bool = false

    @Flag(help: "Start the original VM instead of an ephemeral copy. Useful for creating VM templates")
    var persistent: Bool = false

    @Flag(help: "Skip waiting for the network – useful for debugging")
    var skipNetworkChecks: Bool = false
    private let startTime = Date()

    enum CodingKeys: CodingKey {
        case name
        case handle
        case withGitMirrors
        case waitForever
        case persistent
        case skipNetworkChecks
    }

    let vmManager = VMManager()

    func run() async throws {
        do {
            let configuration = LaunchConfiguration(
                name: self.name,
                handle: self.handle,
                persistent: self.persistent,
                sharedPaths: try self.sharedPaths,
                waitForNetworking: !skipNetworkChecks
            )

            try await vmManager.startVM(configuration: configuration)

            if skipNetworkChecks {
                Console.success("Booting \(name) in progress")
                return
            }

            let ipAddress: IPv4Address
            if waitForever {
                let timeout = Duration.seconds(1_000_000_000) // Doesn't crash like .greatestFiniteMagnitude
                ipAddress = try await vmManager.waitForVMStartup(for: configuration, timeout: timeout)
            } else {
                ipAddress = try await vmManager.waitForVMStartup(for: configuration, timeout: .seconds(30))
            }

            Console.success("Booted \(name) in \(Format.elapsedTime(between: startTime, and: .now))")
            Console.success("- VM Handle: \(self.handle)")
            Console.success("- VM IP Address: \(ipAddress)")
        } catch let error as HostmgrError {
            Console.crash(error)
        }
    }

    var sharedPaths: [LaunchConfiguration.SharedPath] {
        get throws {
            guard try FileManager.default.directoryExists(at: Paths.gitMirrorStorageDirectory) else {
                return []
            }

            guard self.withGitMirrors == true else {
                return []
            }

            return [
                LaunchConfiguration.SharedPath(source: Paths.gitMirrorStorageDirectory, readOnly: true)
            ]
        }
    }
}
