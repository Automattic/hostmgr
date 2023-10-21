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

    var vmLibrary = RemoteVMLibrary()

    let vmManager = VMManager()

    enum CodingKeys: CodingKey {
        case name
    }

    func run() async throws {
        // If we already have the VM ready to go, don't re-download it
        if try await vmManager.hasLocalVM(name: name, state: .ready) {
            Console.exit("VM is present locally", style: .success)
        }

        // If it just needs to be unpacked, try that
        if try await vmManager.hasLocalVM(name: name, state: .packaged) {
            Console.info("Existing package found – extracting")
            try await vmManager.unpackVM(name: name)
            Console.exit("VM is present locally", style: .success)
        }

        // Otherwise download the whole thing
        let vmImage = try await vmLibrary.lookupImage(named: name)

        try await Console.startImageDownload(vmImage) {
            try await vmLibrary.download(vmNamed: name, progressCallback: $0.update)
        }

        // Then unpack it
        try await vmManager.unpackVM(name: name)

        Console.exit("VM is present locally", style: .success)
    }
}
