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

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {
        case source
        case destination
    }

    func run() async throws {
        try await vmManager.cloneVM(from: self.source, to: self.destination)
    }
}
