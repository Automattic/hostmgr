import Foundation
import ArgumentParser
import libhostmgr

struct VMPublishCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "publish",
        abstract: "Publishes a VM for use by other machines"
    )

    enum CodingKeys: CodingKey {
        case name
    }

    @Argument(
        help: "The name of the image you would like to publish"
    )
    var name: String

    let vmLibrary = RemoteVMLibrary()

    func run() async throws {
        let progress = try Console.startImageUpload(Paths.toVMTemplate(named: name))
        try await vmLibrary.publish(vmNamed: name, progressCallback: progress.update)
        progress.succeed()
    }
}
