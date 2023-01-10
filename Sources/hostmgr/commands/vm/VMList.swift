import Foundation
import ArgumentParser
import libhostmgr

struct VMListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that exist on disk on the local machine"
    )

    enum Location: String, CaseIterable {
        case local
        case remote
        case all

        var includesLocal: Bool {
            return self == .local || self == .all
        }

        var includesRemote: Bool {
            return self == .remote || self == .all
        }
    }

    @Option(help: "Filter VMs by location – can be 'remote', 'local', or 'all'.")
    var location: Location = Location.all

    func run() async throws {
        var data = Console.Table()

        if self.location.includesLocal {
            data.append(contentsOf: try LocalVMRepository().list().map(self.format))
        }

        if self.location.includesRemote {
            data.append(contentsOf: try await RemoteVMRepository().listImages().map(self.format))
        }

        Console.printTable(
            data: data,
            columnTitles: ["Location", "Filename", "Size"]
        )
    }

    private func format(localVM: LocalVMImage) throws -> [String] {
        return [
            "Local",
            localVM.basename,
            Format.fileBytes(try localVM.fileSize)
        ]
    }

    private func format(remoteVM: RemoteVMImage) throws -> [String] {
        return [
            "Remote",
            remoteVM.basename,
            Format.fileBytes(remoteVM.imageObject.size)
        ]
    }
}

extension VMListCommand.Location: ExpressibleByArgument {
    var defaultValueDescription: String {
        return self.rawValue
    }

    static var allValueStrings: [String] {
        Self.allCases.map(\.rawValue)
    }
}
