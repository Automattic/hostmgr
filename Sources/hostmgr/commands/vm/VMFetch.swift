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
        try await libhostmgr.fetchRemoteImage(name: self.name)
    }
}
