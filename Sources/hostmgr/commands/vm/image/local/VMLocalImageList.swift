import Foundation
import ArgumentParser

struct VMLocalImageListCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that exist on disk on the local machine"
    )

    func run() throws {
        try VMLocalImageManager()
            .listImageFilePaths()
            .map { $0.lastPathComponent }
            .sorted()
            .forEach { print("\($0)") }
    }
}
