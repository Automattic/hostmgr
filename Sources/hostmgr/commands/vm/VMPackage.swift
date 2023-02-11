import Foundation
import Virtualization
import ArgumentParser
import Cocoa
import libhostmgr

@available(macOS 13.0, *)
struct VMPackageCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract: "Package a VM to move it between computers"
    )

    @Argument(help: "The name of the VM to package")
    var name: String

    mutating func run() async throws {

        try Compressor.compress(
            directory: Paths.toAppleSiliconVM(named: name),
            to: Paths.toArchivedVM(named: name)
        )

        Console.success("Compression Complete")
    }
}
