import Foundation
import ArgumentParser
import libhostmgr

struct VMCleanCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up the VM environment prior to running another job"
    )

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {}

    func run() async throws {
        try await vmManager.resetVMWorkingDirectory()

        // Clean up no-longer-needed local images
        try await vmManager.purgeUnusedImages()
    }
}
