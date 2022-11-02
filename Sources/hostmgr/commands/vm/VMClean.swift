import Foundation
import ArgumentParser
import libhostmgr

struct VMCleanCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up the VM environment prior to running another job"
    )

    func run() throws {
        try libhostmgr.resetVMStorage()
    }
}
