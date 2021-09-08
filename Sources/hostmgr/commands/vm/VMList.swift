import Foundation
import ArgumentParser
import prlctl

struct VMListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VMs, optionally by state"
    )

    @Option(
        name: .shortAndLong,
        help: "Filter VMs by state (running, stopped, or package)"
    )
    var state: VMStatus?

    func run() throws {
        switch state {
            case .running: try printRunningVMs()
            case .stopped: try printStoppedVMs()
            case .packaged: try printPackagedVMs()
            case .suspended: try printSuspendedVMs()
            case .invalid: try printInvalidVMs()
            case nil: try printAllVMs()
        }
    }

    private func printAllVMs() throws {
        try printRunningVMs()
        try printStoppedVMs()
        try printPackagedVMs()
        try printSuspendedVMs()
        try printInvalidVMs()
    }

    private func printRunningVMs() throws {
        try Parallels().lookupRunningVMs().forEach {
            printStatus(status: .running, vm: $0, ip: $0.ipAddress)
        }
    }

    private func printStoppedVMs() throws {
        try Parallels().lookupStoppedVMs().forEach {
            printStatus(status: .stopped, vm: $0)
        }
    }

    private func printSuspendedVMs() throws {
        try Parallels().lookupSuspendedVMs().forEach {
            printStatus(status: .suspended, vm: $0)
        }
    }

    private func printPackagedVMs() throws {
        try Parallels().lookupPackagedVMs().forEach {
            printStatus(status: .packaged, vm: $0)
        }
    }

    private func printInvalidVMs() throws {
        try Parallels().lookupInvalidVMs().forEach {
            printStatus(status: .invalid, vm: $0)
        }
    }

    private func printStatus(status: VMStatus, vm: VMProtocol, ip: String? = nil) {
        print("\(status.rawValue)\t\(vm.name)\t\(vm.uuid)")
    }
}

extension VMStatus: ExpressibleByArgument {

}
