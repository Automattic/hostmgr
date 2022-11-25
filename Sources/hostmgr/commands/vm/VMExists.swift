import Foundation
import ArgumentParser
import libhostmgr

struct VMExistsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exists",
        abstract: "Exits with code 0 if the named VM exists. Otherwise exits with code 1"
    )

    @Argument(help: "The exact name of the VM")
    var name: String

    func run() async throws {
        guard let localVM = try await LocalVMRepository.shared.lookupVM(withName: self.name) else {
            Console.crash(message: "There is no local VM named \(self.name)", reason: .fileNotFound)
        }

        Console.success("VM \(localVM.basename) exists")
    }
}
