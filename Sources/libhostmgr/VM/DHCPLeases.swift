import Foundation
import Network
import Virtualization

public struct DHCPLease {
    let name: String
    let ipAddress: IPv4Address
    let hwAddress: VZMACAddress
    let identifier: VZMACAddress
    let expirationDate: Date

    public static func mostRecentLease(forMACaddress address: VZMACAddress) throws -> DHCPLease? {
        try leasesFrom(file: URL(fileURLWithPath: "/private/var/db/dhcpd_leases"))
            .filter { $0.hwAddress == address }
            .sorted(by: \.expirationDate)
            .first
    }

    static func leasesFrom(file url: URL) throws -> [DHCPLease] {
        var parser = DHCPLeaseFileParser()
        try parser.parse(file: url)
        return parser.leases
    }
}

struct DHCPLeaseFileParser {

    var leases = [DHCPLease]()

    var name: String?
    var ipAddress: IPv4Address?
    var hwAddress: VZMACAddress?
    var identifier: VZMACAddress?
    var expirationDate: Date?

    mutating func parse(file: URL) throws {
        try parse(string: String(contentsOf: file))
    }

    mutating func parse(string: String) {
        string
            .split(separator: "\n")
            .map(String.init)
            .forEach { process(line:$0) }
    }

    mutating func process(line: String) {
        if line == "{" {
            self.reset()
        } else if line == "}" {
            self.processLease()
        } else if line.trimmingWhitespace.starts(with: "name=") {
            name = valueFor(line: line)
        } else if line.trimmingWhitespace.starts(with: "ip_address=") {
            ipAddress = ipAddressFor(line: line)
        } else if line.trimmingWhitespace.starts(with: "hw_address=") {
            hwAddress = hardwareAddressFor(line: line)
        } else if line.trimmingWhitespace.starts(with: "identifier=") {
            identifier = hardwareAddressFor(line: line)
        } else if line.trimmingWhitespace.starts(with: "lease=") {
            expirationDate = dateFor(line: line)
        }
    }

    func valueFor(line: String) -> String? {
        let lineParts = line.split(separator: "=")
        precondition(lineParts.count == 2)
        guard let value = lineParts.last else {
            return nil
        }
        return String(value)
    }

    func ipAddressFor(line: String) -> IPv4Address? {
        guard let ip = valueFor(line: line) else {
            return nil
        }

        return IPv4Address(ip)
    }

    func hardwareAddressFor(line: String) -> VZMACAddress? {
        let addressParts = valueFor(line: line)?.split(separator: ",")
        guard
            addressParts?.count == 2,
            let macAddress = addressParts?.last
        else {
            return nil
        }

        // Correct for elided leading zeros in the MAC address
        let fixedAddress = macAddress
            .components(separatedBy: ":")
            .map { octet in
                switch octet.count {
                    case 0: return "00"
                    case 1: return "0" + octet
                    case 2: return String(octet)
                    default: preconditionFailure("This hardware address is invalid")
                }
            }
            .joined(separator: ":")

        return VZMACAddress(string: fixedAddress)
    }

    func dateFor(line: String) -> Date? {
        guard
            let value = valueFor(line: line),
            let timestamp = UInt64(value.dropFirst(2), radix: 16)
        else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    mutating func processLease() {
        guard
            let name = self.name,
            let ipAddress = self.ipAddress,
            let hwAddress = self.hwAddress,
            let identifier = self.identifier,
            let expirationDate = self.expirationDate
        else {
            return
        }

        self.leases.append(DHCPLease(
            name: name,
            ipAddress: ipAddress,
            hwAddress: hwAddress,
            identifier: identifier,
            expirationDate: expirationDate
        ))
    }

    mutating func reset() {
        self.name = nil
        self.ipAddress = nil
        self.hwAddress = nil
        self.identifier = nil
        self.expirationDate = nil
    }
}
