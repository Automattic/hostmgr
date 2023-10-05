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

    @Option(help: "A handle that can be used to reference the VM later (useful for shutting down a specific VM)")
    var handle: String = UUID().uuidString

    @Flag(help: "Mount the system git mirrors directory into the virtual machine on startup?")
    var withGitMirrors: Bool = false

    @Flag(help: "Wait indefinitely for the SSH server to become available (useful when provisioning a new image")
    var waitForever: Bool = false

    @Flag(help: "Start the original VM instead of an ephemeral copy. Useful for creating VM templates")
    var persistent: Bool = false

    private let startTime = Date()

    enum CodingKeys: CodingKey {
        case name
        case handle
        case withGitMirrors
        case waitForever
        case persistent
    }

    @DIInjected
    var vmManager: any VMManager

    func run() async throws {
        do {
            try await vmManager.startVM(configuration: LaunchConfiguration(
                name: self.name,
                handle: self.handle,
                persistent: self.persistent,
                sharedPaths: self.sharedPaths
            ))

            try await vmManager.waitForVMStartup(name: name)

            Console.success("Booted \(name) in \(Format.elapsedTime(between: startTime, and: .now))")
        } catch let error as HostmgrXPCError {
            Console.crash(error)
        }
    }

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
