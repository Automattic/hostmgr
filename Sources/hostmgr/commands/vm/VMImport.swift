import Foundation
import ArgumentParser
import prlctl

struct VMImportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import a downloaded VM, making it available for use"
    )

    @Option(
        name: .shortAndLong,
        help: "The file path to the VM package you'd like to import"
    )
    var path: URL

    @Flag(help: "Overwrite an existing VM, if needed?")
    var overwrite: Bool = false

    func run() throws {

        let vmName = self.path.basename
        let url = self.path
        let path = path.path

        let existingVMNames = try Parallels().lookupAllVMs().map { $0.name }

        if existingVMNames.contains(vmName) {
            if !overwrite {
                print("Unable to import this VM – there is an existing VM with this name")
                Self.exit()
            }

            try Parallels().lookupVM(named: vmName)?.delete()
        }

        guard FileManager.default.fileExists(atPath: path) else {
            print("There is no file at \(path)")
            Self.exit()
        }

        guard let vm = try Parallels().importVM(at: url) else {
            print("Unable to import VM at \(path)")
            Self.exit()
        }

        guard let package = vm.asPackagedVM() else {
            throw CleanExit.message("Imported \(vm.name)")
        }

        print("Unpacking the VM – this will take a few minutes")
        try package.unpack()

        print("Imported Complete")
        print("\tName:\t\(vm.name)")
        print("\tUUID:\t\(vm.uuid)")
    }
}
