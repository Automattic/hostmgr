import Foundation
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

    func run() async throws {

        guard try LocalVMRepository().lookupVM(withName: name) == nil else {
            Console.exit(
                message: "VM is present locally",
                style: .success
            )
        }

        try await libhostmgr.fetchRemoteImage(name: self.name)
    }
}
