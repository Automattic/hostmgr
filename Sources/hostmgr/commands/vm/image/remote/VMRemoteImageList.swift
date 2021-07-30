import Foundation
import ArgumentParser
import SotoS3

struct VMRemoteImageListCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available VM images"
    )

    func run() throws {
        let imageManager = VMRemoteImageManager()
        try imageManager.list().forEach {
            print($0)
        }
    }
}
