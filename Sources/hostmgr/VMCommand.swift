import Foundation
import ArgumentParser
import prlctl

struct VMCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Allows working with VMs",
        subcommands: [
            VMListCommand.self,
            VMStartCommand.self,
            VMStopCommand.self,
            VMDetailsCommand.self,
            VMDeleteCommand.self,
            VMCloneCommand.self,
            VMCleanCommand.self,
            VMImportCommand.self,
            VMImageCommand.self,
            VMExistsCommand.self,
        ]
    )
}

// Allow passing VM objects directly
extension VM: ExpressibleByArgument {

    public init?(argument: String) {

        guard let vm = try? Parallels().lookupVM(named: argument) else {
            return nil
        }

        self.init(from: vm)
    }

    public static var allValueStrings: [String] {
        guard let vms = try? Parallels().lookupAllVMs() else {
            return []
        }

        let names = vms.map { $0.name }
        let uuids = vms.map { $0.uuid }

        return names + uuids
    }
}

extension StoppedVM: ExpressibleByArgument {
    public init?(argument: String) {
        guard let vm = try? Parallels().lookupStoppedVMs().first(where: { $0.name == argument || $0.uuid == argument }) else {
            return nil
        }

        self.init(vm: vm)
    }

    public static var allValueStrings: [String] {
        guard let vms = try? Parallels().lookupStoppedVMs() else {
            return []
        }

        let names = vms.map { $0.name }
        let uuids = vms.map { $0.uuid }

        return names + uuids
    }
}

extension RunningVM: ExpressibleByArgument {
    public init?(argument: String) {
        guard let vm = try? Parallels().lookupRunningVMs().first(where: { $0.name == argument || $0.uuid == argument }) else {
            return nil
        }

        self.init(vm: vm)
    }

    public static var allValueStrings: [String] {
        guard let vms = try? Parallels().lookupRunningVMs() else {
            return []
        }

        let names = vms.map { $0.name }
        let uuids = vms.map { $0.uuid }

        return names + uuids
    }
}
