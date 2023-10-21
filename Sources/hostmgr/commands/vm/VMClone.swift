import Foundation
import ArgumentParser
import libhostmgr

struct VMCloneCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clone",
        abstract: "Clone a VM template into another persistent VM"
    )

    @Argument
    var source: String

    @Argument
    var destination: String

    let vmManager = VMManager()

    enum CodingKeys: CodingKey {
        case source
        case destination
    }

    func run() async throws {
        try await vmManager.cloneVM(source: self.source, destination: self.destination)
    }
}
