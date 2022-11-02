import Foundation
import ArgumentParser
import libhostmgr

struct VMCleanCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up the VM environment prior to running another job"
    )

    func run() throws {
        let repository = LocalVMRepository(imageDirectory: FileManager.default.temporaryDirectory)
        try repository.list().forEach { localVM in
            Console.info("Removing temp VM file for \(localVM.filename)")
            try repository.delete(image: localVM)
        }

        try ParallelsVMRepository().lookupVMs().forEach { parallelsVM in
            Console.info("Removing Registered VM \(parallelsVM.name)")
            try parallelsVM.unregister()
        }

        Console.success("Cleanup Complete")
    }
}
