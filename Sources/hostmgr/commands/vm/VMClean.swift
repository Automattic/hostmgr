import Foundation
import ArgumentParser
import libhostmgr

struct VMCleanCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up the VM environment prior to running another job"
    )

    func run() async throws {
        try libhostmgr.resetVMStorage()

        // Clean up no-longer-needed local images
        let deleteList = try await libhostmgr.listLocalImagesToDelete()
        try libhostmgr.deleteLocalImages(list: deleteList)
    }
}
