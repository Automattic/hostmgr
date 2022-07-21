import Foundation
import ArgumentParser
import SotoS3

struct VMRemoteImageListCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that are available for download from the server"
    )

    func run() throws {
        let imageManager = VMRemoteImageManager()
        try imageManager.list().forEach {
            print($0)
        }
    }
}
