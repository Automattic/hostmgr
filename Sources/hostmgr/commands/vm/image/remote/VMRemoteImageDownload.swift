import Foundation
import ArgumentParser
import libhostmgr

struct VMRemoteImageDownload: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download a given image and set it up for use"
    )

    @Argument(
        help: "The name of the image you would like to download"
    )
    var name: String

    func run() async throws {
        try await libhostmgr.downloadRemoteImage(name: self.name)
    }
}
