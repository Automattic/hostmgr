import Foundation
import Network
import Virtualization

public struct DHCPLease {
    public let name: String
    public let ipAddress: IPv4Address
    public let hwAddress: VZMACAddress
    let identifier: VZMACAddress
    public let expirationDate: Date

    enum Errors: Error {
        case noIpAddressAssigned
        case ipAddressNoLongerValid
    }

    public static func hasValidLease(forMACaddress address: VZMACAddress) throws -> Bool {
        try !leases(for: address).filter { !$0.isExpired }.isEmpty
    }

    public static func mostRecentLease(forMACaddress address: VZMACAddress) throws -> DHCPLease {

        let leases = try leases(for: address)

        guard !leases.isEmpty else {
            throw Errors.noIpAddressAssigned
        }

        guard let lease = leases.filter({ $0.isExpired }).sorted(by: \.expirationDate).first else {
            throw Errors.ipAddressNoLongerValid
        }

        return lease
    }

    static func leases(for address: VZMACAddress) throws -> [DHCPLease] {
        try leasesFrom(file: URL(fileURLWithPath: "/private/var/db/dhcpd_leases"))
            .lazy
            .filter { $0.hwAddress == address }
    }

    static func leasesFrom(file url: URL) throws -> [DHCPLease] {
        var parser = DHCPLeaseFileParser()
        try parser.parse(file: url)
        return parser.leases
    }

    var isExpired: Bool {
        expirationDate > Date()
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
            .forEach { process(line: $0) }
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
        guard let ipAddressString = valueFor(line: line) else {
            return nil
        }

        return IPv4Address(ipAddressString)
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
            .map(self.correctHardwareAddressOctet)
            .joined(separator: ":")

        return VZMACAddress(string: fixedAddress)
    }

    func correctHardwareAddressOctet(_ octet: String) -> String {
        switch octet.count {
        case 0: return "00"
        case 1: return "0" + octet
        case 2: return String(octet)
        default: preconditionFailure("This hardware address is invalid")
        }
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
