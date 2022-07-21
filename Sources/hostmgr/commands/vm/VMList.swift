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
        case .resuming: try printResumingVMs()
        case .invalid: try printInvalidVMs()
        case .starting: try printStartingVMs()
        case .stopping: try printStartingVMs()
        case nil: try printAllVMs()
        }
    }

    private func printAllVMs() throws {
        try printRunningVMs()
        try printStoppedVMs()
        try printPackagedVMs()
        try printSuspendedVMs()
        try printInvalidVMs()
        try printStartingVMs()
        try printStoppingVMs()
    }

    private func printRunningVMs() throws {
        try Parallels().lookupRunningVMs().forEach {
            printStatus(status: .running, virtualMachine: $0, ipAddress: $0.ipAddress)
        }
    }

    private func printStoppedVMs() throws {
        try Parallels().lookupStoppedVMs().forEach {
            printStatus(status: .stopped, virtualMachine: $0)
        }
    }

    private func printSuspendedVMs() throws {
        try Parallels().lookupSuspendedVMs().forEach {
            printStatus(status: .suspended, virtualMachine: $0)
        }
    }

    private func printPackagedVMs() throws {
        try Parallels().lookupPackagedVMs().forEach {
            printStatus(status: .packaged, virtualMachine: $0)
        }
    }

    private func printInvalidVMs() throws {
        try Parallels().lookupInvalidVMs().forEach {
            printStatus(status: .invalid, virtualMachine: $0)
        }
    }

    private func printStartingVMs() throws {
        try Parallels().lookupStartingVMs().forEach {
            printStatus(status: .starting, virtualMachine: $0)
        }
    }

    private func printStoppingVMs() throws {
        try Parallels().lookupStoppingVMs().forEach {
            printStatus(status: .stopping, virtualMachine: $0)
        }
    }

    private func printResumingVMs() throws {
        try Parallels().lookupStoppingVMs().forEach {
            printStatus(status: .resuming, virtualMachine: $0)
        }
    }

    private func printStatus(
        status: VMStatus,
        virtualMachine: VMProtocol,
        ipAddress: String? = nil
    ) {
        print("\(status.rawValue)\t\(virtualMachine.name)\t\(virtualMachine.uuid)")
    }
}

extension VMStatus: ExpressibleByArgument {

}
