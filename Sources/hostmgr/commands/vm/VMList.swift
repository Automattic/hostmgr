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
            case .suspended: debugPrint("It's not currently possible to look up suspended VMs")
            case .invalid: debugPrint("It's not currently possible to look up invalid VMs")
            case nil: try printAllVMs()
        }
    }

    private func printAllVMs() throws {
        try printRunningVMs()
        try printStoppedVMs()
    }

    private func printRunningVMs() throws {
        try Parallels().lookupRunningVMs().forEach {
            print("running\t\($0.name)\t\($0.uuid)\t\($0.ipAddress)")
        }
    }

    private func printStoppedVMs() throws {
        try Parallels().lookupStoppedVMs().forEach {
            print("stopped\t\($0.name)\t\($0.uuid)")
        }
    }

    private func printPackagedVMs() throws {
        try Parallels().lookupPackagedVMs().forEach {
            print("packaged\t\($0.name)\t\($0.uuid)")
        }
    }
}

extension VMStatus: ExpressibleByArgument {

}
