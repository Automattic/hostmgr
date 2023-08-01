import Foundation
import ArgumentParser
import libhostmgr
import Network

struct VMDetailsCommand: AsyncParsableCommand {

    enum Detail: EnumerableFlag {
        case ipAddress
        case all
    }

    static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Shows information about a given VM"
    )

    @Argument(
        help: "The VM to fetch details for"
    )
    var name: String

    @Flag(exclusivity: .exclusive)
    var detail: Detail = .all

    @DIInjected
    var vmManager: any VMManager

    enum CodingKeys: CodingKey {}

    func run() async throws {
//        let address = try await vmManager.ipAddress(forVmWithName: self.virtualMachine)
//        print("IPv4 Address:\t\(address)")
    }
}

#if arch(arm64)
extension VMDetailsCommand {
    func ipAddressString(for bundle: VMBundle) -> String {
        guard let ipAddress = try? bundle.currentDHCPLease?.ipAddress else {
            return "-"
        }

        return ipAddress.debugDescription
    }

    func relativeLeaseExpirationString(for bundle: VMBundle) -> String {
        guard let expirationDate = try? bundle.currentDHCPLease?.expirationDate else {
            return "-"
        }

        return Format.remainingTime(until: expirationDate, context: .beginningOfSentence)
    }
}
#endif
