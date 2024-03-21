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
        case noResume
    }

    @Argument(
        help: "The name of the image you would like to publish"
    )
    var name: String

    @Flag(help: "Do not attempt to resume previous uncompleted uploads")
    var noResume = false

    let vmLibrary = RemoteVMLibrary()

    func run() async throws {
        let progress = try Console.startImageUpload(Paths.toArchivedVM(named: name))
        try await vmLibrary.publish(vmNamed: name, allowResume: !noResume, progressCallback: progress.update)
        progress.succeed()
    }
}
