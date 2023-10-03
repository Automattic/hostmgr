import Foundation
import ArgumentParser
import libhostmgr
import Network

struct VMDetailsCommand: AsyncParsableCommand {

    enum Detail: EnumerableFlag {
        case ipAddress
        case path
        case workingPath
        case all
    }

    static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Shows information about a given VM"
    )

    @Argument(
        help: "The VM to fetch details for"
    )
    var handle: String

    @Flag(exclusivity: .exclusive)
    var detail: Detail = .all

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {
        case handle
        case detail
    }

    func run() async throws {
        let ipAddress = try await vmManager.ipAddress(forVmWithName: handle)
        let templateName = try await vmManager.vmTemplateName(forVmWithName: handle) ?? handle
        let path = Paths.toVMTemplate(named: templateName).path()
        let workingPath = Paths.toWorkingAppleSiliconVM(named: handle).path()

        switch detail {
            case .ipAddress: print(ipAddress)
            case .path: print(path)
            case .workingPath: print(workingPath)
            case .all:
                print("Path:\t\t\(path)")
                print("Working Path:\t\(workingPath)")
                print("IPv4 Address:\t\(ipAddress)")
        }
    }
}
