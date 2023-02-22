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
        let bundle = try VMBundle.fromExistingBundle(at: Paths.toAppleSiliconVM(named: name))
        let template = try VMTemplate.creatingTemplate(fromBundle: bundle).validate()
        try template.compress()
    }
}
