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

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {
        case name
    }

    func run() async throws {
        guard try await vmManager.hasLocalVM(name: name, state: .ready) else {
            Console.crash(.localVMNotFound(name))
        }

        Console.success("VM \(name) exists")
    }
}
