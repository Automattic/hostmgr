import Foundation
import ArgumentParser
import libhostmgr

struct VMListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List VM images that exist on disk on the local machine"
    )

    enum Location{
        case local
        case remote
        case all
    }

    func run() throws {
        Console.printTable(
            data: try LocalVMRepository().list().map(self.format),
            columnTitles: ["Filename", "Size"]
        )
    }

    private func format(localVM: LocalVMImage) throws -> [String] {
        return [
            localVM.filename,
            Format.fileBytes(try localVM.fileSize)
        ]
    }

    private func format(remoteVM: RemoteVMImage) throws -> [String] {
        return [
            remoteVM.basename,
            Format.fileBytes(remoteVM.imageObject.size)
        ]
    }
}
