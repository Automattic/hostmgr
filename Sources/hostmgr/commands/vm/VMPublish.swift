import Foundation
import ArgumentParser
import libhostmgr

struct VMPublish: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "publish",
        abstract: "Publishes a VM for use by other machines"
    )

    @Argument(
        help: "The name of the image you would like to publish"
    )
    var name: String

    func run() async throws {
        
    }
}
