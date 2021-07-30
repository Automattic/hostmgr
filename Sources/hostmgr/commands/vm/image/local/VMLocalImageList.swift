import Foundation
import ArgumentParser

struct VMLocalImageListCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available VM images"
    )

    func run() throws {
        let images =  try VMLocalImageManager().list()
        images.sorted().forEach { print("\($0)") }
    }
}
