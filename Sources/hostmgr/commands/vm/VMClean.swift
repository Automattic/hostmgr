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
        try repository.list().forEach { vm in
            Console.info("Removing temp VM file for \(vm.filename)")
            try repository.delete(image: vm)
        }

        try ParallelsVMRepository().lookupVMs().forEach { vm in
            Console.info("Removing Registered VM \(vm.name)")
            try vm.unregister()
        }

        Console.success("Cleanup Complete")
    }
}
