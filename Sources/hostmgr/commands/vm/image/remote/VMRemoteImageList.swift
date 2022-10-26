import Foundation
import ArgumentParser
import SotoS3

struct VMRemoteImageListCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that are available for download from the server"
    )

    func run() async throws {
        let imageNames = try await VMRemoteImageManager()
            .list()
            .map(\.basename)
            .sorted()

        for image in imageNames {
            print("\(image)")
        }
    }
}
