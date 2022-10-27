import Foundation
import ArgumentParser
import libhostmgr

struct VMExistsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exists",
        abstract: "Exits with code 0 if the named VM exists. Otherwise exits with code 1"
    )

    @Argument(help: "The exact name of the VM")
    var name: String

    func run() throws {
        _ = try libhostmgr.lookupParallelsVMOrExit(withIdentifier: self.name)
        Console.success("VM \(self.name) exists")
    }
}
