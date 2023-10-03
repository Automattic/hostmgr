import Foundation
import ArgumentParser
import libhostmgr

struct VMPublish: AsyncParsableCommand {

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

    @DIInjected
    var vmLibrary: any RemoteVMLibrary

    func run() async throws {
        let progress = try Console.startImageUpload(Paths.toVMTemplate(named: name))
        try await vmLibrary.publish(vmNamed: name, progressCallback: progress.update)
        progress.succeed()
    }
}
