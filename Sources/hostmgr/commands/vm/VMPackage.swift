import Foundation
import Virtualization
import ArgumentParser
import Cocoa
import libhostmgr

#if arch(arm64)
struct VMPackageCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract: "Package a VM to move it between computers"
    )

    @Argument(help: "The name of the VM to package")
    var name: String

    mutating func run() async throws {
        let bundle = try VMBundle.fromExistingBundle(at: Paths.toAppleSiliconVM(named: name))
        Console.info("Creating Template")
        let template = try VMTemplate.creatingTemplate(fromBundle: bundle)
        Console.success("Template Created")

        Console.info("Compressing Template")
        try template.validate().compress()
        Console.success("Compression Complete")
    }
}
#endif
