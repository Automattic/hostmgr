import XCTest
import Network
import Virtualization
@testable import libhostmgr

final class DHCPLeaseTests: XCTestCase {

    func testThatLeasesCanBeParsed() throws {
        XCTAssertEqual(2, try parseLeases().count)
    }

    func testThatDeviceNameCanBeParsed() throws {
        XCTAssertEqual("my-device", try parseLeases()[0].name)
        XCTAssertEqual("AppleViMachine1", try parseLeases()[1].name)
    }

    func testThatDeviceIPcanBeParsed() throws {
        XCTAssertEqual(IPv4Address("192.168.64.7"), try parseLeases()[0].ipAddress)
        XCTAssertEqual(IPv4Address("192.168.65.9"), try parseLeases()[1].ipAddress)
    }

    func testThatDeviceMACaddressCanBeParsed() throws {
        XCTAssertEqual(VZMACAddress(string: "6e:97:39:e2:b9:28"), try parseLeases()[0].hwAddress)
        XCTAssertEqual(VZMACAddress(string: "6e:97:39:e2:b9:28"), try parseLeases()[0].identifier)

        XCTAssertEqual(VZMACAddress(string: "92:50:29:22:66:8b"), try parseLeases()[1].hwAddress)
        XCTAssertEqual(VZMACAddress(string: "92:50:29:22:66:8b"), try parseLeases()[1].identifier)

    }

    func testThatLeaseExpirationDateCanBeParsed() throws {
        XCTAssertEqual(Date(timeIntervalSince1970: 1677384464), try parseLeases()[0].expirationDate)
        XCTAssertEqual(Date(timeIntervalSince1970: 1693589515), try parseLeases()[1].expirationDate)
    }

    func testThatShortformMACaddressesCanBeParsed() throws {
        XCTAssertEqual(
            VZMACAddress(string: "3e:11:0e:50:7b:0f"),
            DHCPLeaseFileParser().hardwareAddressFor(line: "hw_address=1,3e:11:e:50:7b:f")
        )
    }

    func testThatShortformMACaddressesWithElidedSegmentsCanBeParsed() throws {
        XCTAssertEqual(
            VZMACAddress(string: "3e:11:00:00:00:00"),
            DHCPLeaseFileParser().hardwareAddressFor(line: "hw_address=1,3e:11::::")
        )
    }

    private func parseLeases() throws -> [DHCPLease] {
        try DHCPLease.leasesFrom(file: pathForResource(named: "dhcpd_leases"))
    }
}
