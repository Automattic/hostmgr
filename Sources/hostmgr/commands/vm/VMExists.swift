import Foundation
import ArgumentParser
import prlctl

struct VMExistsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exists",
        abstract: "Exits with code 0 if the named VM exists. Otherwise exits with code 1"
    )

    @Argument(help: "The exact name of the VM")
    var name: String

    func run() throws {

        let existingVMNames = try Parallels().lookupAllVMs().map { $0.name }

        logger.debug("Existing VMs:")
        existingVMNames.forEach { logger.debug("\t\($0)") }

        guard existingVMNames.contains(name) else {
            logger.debug("VM \(name) does not exist")
            throw ExitCode(rawValue: 1)
        }

        logger.debug("VM \(name) exists")
    }
}
