import Foundation
import ArgumentParser
import libhostmgr

struct VMRemoteImageListCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that are available for download from the server"
    )

    func run() async throws {
        Console.printTable(
            data: try await RemoteVMRepository().listImages().map(self.format),
            columnTitles: ["Filename", "Size"]
        )
    }

    private func format(_ remoteImage: RemoteVMImage) -> [String] {
        return [
            remoteImage.fileName,
            Format.fileBytes(remoteImage.imageObject.size)
        ]
    }
}
