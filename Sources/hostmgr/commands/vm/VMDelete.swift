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
    var vm: StoppedVM?

    @Option(
        name: .shortAndLong,
        help: "Delete any VMs starting with the given string"
    )
    var startingWith: String?

    func run() throws {
        try vm?.delete()

        if let prefix = startingWith {
            try VMLocalImageManager().lookupStoppedVMsBy(prefix: prefix).forEach { try $0.delete() }
        }
    }
}
