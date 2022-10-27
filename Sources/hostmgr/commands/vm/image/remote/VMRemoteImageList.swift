import Foundation
import ArgumentParser
import libhostmgr

struct VMRemoteImageListCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that are available for download from the server"
    )

    func run() async throws {
        let imageNames = try await RemoteVMRepository()
            .listImages()
            .map(\.basename)
            .sorted()

        for image in imageNames {
            print("\(image)")
        }
    }
}
