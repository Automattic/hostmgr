import Foundation
import ArgumentParser
import prlctl

struct VMCleanCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Cleans up a VM prior to it being reused"
    )

    @Option(
        name: .shortAndLong,
        help: "The VM to clean"
    )
    var vm: StoppedVM
    
    func run() throws {
        try vm.clean()
    }
}
