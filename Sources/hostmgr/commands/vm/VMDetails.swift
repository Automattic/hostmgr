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

    func run() async throws {
        #if arch(arm64)
        guard let localVM = try LocalVMRepository().lookupVM(withName: name) else {
            Console.crash(message: "There is no local VM called `\(name)`", reason: .fileNotFound)
        }

        let bundle = try VMBundle.fromExistingBundle(at: localVM.path)

        do {
            let ipAddress = try bundle.currentDHCPLease?.ipAddress

            switch detail {
            case .ipAddress: print("\(ipAddress)")
            case .all:
                Console.printTable(
                    data: [
                        ["Name:", localVM.basename],
                        ["State:", localVM.state.rawValue],
                        ["Location:", bundle.root.path],
                        ["MAC Address:", bundle.macAddress.string],
                        ["IPv4 Address:", ipAddressString(for: bundle)],
                        ["IPv4 Lease Expires:", relativeLeaseExpirationString(for: bundle)]
                    ]
                )
            }
        } catch {
            if detail == .ipAddress {
                throw error
            } else {
                Console.info("It looks like this VM is not currently running")
            }
        }
        #else
        guard
            let virtualMachine = try ParallelsVMRepository().lookupVM(byIdentifier: name),
            let runningVirtualMachine = virtualMachine.asRunningVM()
        else {
            Console.crash(message: "There is no local VM called `\(name)`", reason: .fileNotFound)
        }

        guard runningVirtualMachine.hasIpV4Address else {
            Console.crash(message: "Couldn't find an IP for `\(name)` – is it running?", reason: .invalidVMStatus)
        }

        switch detail {
            case .ipAddress: print(runningVirtualMachine.ipAddress)
            case .all:
                Console.printTable(
                    data: [
                        ["Name:", runningVirtualMachine.name],
                        ["UUID:", runningVirtualMachine.uuid],
                        ["IPv4 Address:", runningVirtualMachine.ipAddress],
                    ]
                )
        }
        #endif
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
