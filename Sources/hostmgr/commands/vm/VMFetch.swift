import ArgumentParser
import libhostmgr

struct VMFetchCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Download a given image if it's not already present"
    )

    @Argument(
        help: "The name of the image you would like to download"
    )
    var name: String

    @DIInjected
    var vmProvider: any VMProvider

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {
        case name
    }

    func run() async throws {
        // If we already have the VM ready to go, don't re-download it
        if try await vmManager.hasLocalVM(name: name, state: .ready) {
            Console.exit(message: "VM is present locally", style: .success)
        }

        // If it just needs to be unpacked, try that
        if try await vmManager.hasLocalVM(name: name, state: .packaged) {
            try await vmManager.unpackVM(name: name)
        }

        // Otherwise do the whole thing
        try await vmProvider.fetchRemoteImage(name: name)
    }
}
