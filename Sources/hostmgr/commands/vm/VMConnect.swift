import Foundation
import AppKit
import ArgumentParser
import libhostmgr

struct VMConnectCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "connect",
        abstract: "Open a VNC connection to the given machine"
    )

    @Argument(
        help: "The VM to fetch details for"
    )
    var handle: String

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {
        case handle
    }

    func run() async throws {
        let ipAddress = try await vmManager.ipAddress(forVmWithName: handle)
        let url = URL(string: "vnc://\(ipAddress)")!
        NSWorkspace.shared.open(url)
    }
}
