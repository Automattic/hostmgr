import Foundation
import Virtualization
import ArgumentParser
import Cocoa
import libhostmgr

struct VMPackageCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract: "Package a VM to move it between computers"
    )

    @Argument(help: "The name of the VM to package")
    var name: String

    mutating func run() async throws {
        try await VMManager().packageVM(name: name)
    }
}
