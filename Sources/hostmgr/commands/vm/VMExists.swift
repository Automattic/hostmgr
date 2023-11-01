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

    let vmManager = VMManager()

    enum CodingKeys: CodingKey {
        case name
    }

    func run() async throws {
        guard try vmManager.hasLocalVMTemplate(named: name) || vmManager.hasTempVM(named: name) else {
            Console.crash(.localVMNotFound(name))
        }

        Console.success("VM \(name) exists")
    }
}
