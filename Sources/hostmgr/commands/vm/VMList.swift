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

    let vmManager = VMManager()

    let vmRemote = RemoteVMLibrary()

    enum CodingKeys: CodingKey {
        case location
    }

    func run() async throws {
        var data = Console.Table()

        if self.location.includesLocal {
            data.append(contentsOf: try await vmManager.list(sortedBy: .name).map(self.format))
        }

        if self.location.includesRemote {
            data.append(contentsOf: try await vmRemote.listImages().map(self.format))
        }

        Console.printTable(
            data: data,
            columnTitles: ["Location", "Filename", "State", "Size"]
        )
    }

    private func format(localVM: LocalVMImage) throws -> Console.TableRow {
        return [
            "💻 Local",
            localVM.name,
            localVM.state.rawValue,
            Format.fileBytes(try localVM.fileSize)
        ]
    }

    private func format(remoteVM: RemoteVMImage) throws -> Console.TableRow {
        return [
            "🌐 Remote",
            remoteVM.name,
            VMImageState.packaged.rawValue,
            Format.fileBytes(remoteVM.size)
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
