import Foundation
import ArgumentParser
import prlctl

struct VMDeleteCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Deletes a VM"
    )

    @Argument(
        help: "The name of the VM to delete"
    )
    var virtualMachine: StoppedVM?

    @Option(
        name: .shortAndLong,
        help: "Delete any VMs starting with the given string"
    )
    var startingWith: String?

    func run() throws {
        try virtualMachine?.delete()

        if let prefix = startingWith {
            try VMLocalImageManager().lookupVMsBy(prefix: prefix).forEach { try $0.delete() }
        }
    }
}
