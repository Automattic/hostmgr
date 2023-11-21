import XCTest
@testable import libhostmgr

final class VMConfigurationTests: XCTestCase {
    let min: UInt64 = 4_194_304
    let hostReservedRAM: UInt64 = 1024 * 1024 * 4096

    func testThatMemorySizeCalculationsAreValidForUnshared8GBCapacity() throws {
        let max: UInt64 = 8_589_934_592
        let configuration = try VMConfiguration(
            diskImagePath: URL(fileURLWithPath: "/dev/null"),
            macAddress: .randomLocallyAdministered()
        )

        XCTAssertEqual(configuration.calculateMemorySize(
            min: min,
            max: max,
            hostReserved: hostReservedRAM,
            shared: false
        ), 4_294_967_296)
    }

    func testThatMemorySizeCalculationsAreValidForShared8GBCapacity() throws {
        let max: UInt64 = 8_589_934_592
        let configuration = try VMConfiguration(
            diskImagePath: URL(fileURLWithPath: "/dev/null"),
            macAddress: .randomLocallyAdministered()
        )

        XCTAssertEqual(configuration.calculateMemorySize(
            min: min,
            max: max,
            hostReserved: hostReservedRAM,
            shared: true
        ), 2_147_483_648)
    }

    func testThatMemorySizeCalculationsAreValidForUnshared16GBCapacity() throws {
        let max: UInt64 = 17_179_869_184
        let configuration = try VMConfiguration(
            diskImagePath: URL(fileURLWithPath: "/dev/null"),
            macAddress: .randomLocallyAdministered()
        )

        XCTAssertEqual(configuration.calculateMemorySize(
            min: min,
            max: max,
            hostReserved: hostReservedRAM,
            shared: false
        ), 12_884_901_888)
    }

    func testThatMemorySizeCalculationsAreValidForShared16GBCapacity() throws {
        let max: UInt64 = 17_179_869_184
        let configuration = try VMConfiguration(
            diskImagePath: URL(fileURLWithPath: "/dev/null"),
            macAddress: .randomLocallyAdministered()
        )

        XCTAssertEqual(configuration.calculateMemorySize(
            min: min,
            max: max,
            hostReserved: hostReservedRAM,
            shared: true
        ), 6_442_450_944)
    }

    func testThatMemorySizeCalculationsAreValidForUnshared32GBCapacity() throws {
        let max: UInt64 = 34_359_738_368
        let configuration = try VMConfiguration(
            diskImagePath: URL(fileURLWithPath: "/dev/null"),
            macAddress: .randomLocallyAdministered()
        )

        XCTAssertEqual(configuration.calculateMemorySize(
            min: min,
            max: max,
            hostReserved: hostReservedRAM,
            shared: false
        ), 30_064_771_072)
    }

    func testThatMemorySizeCalculationsAreValidForShared32GBCapacity() throws {
        let max: UInt64 = 34_359_738_368
        let configuration = try VMConfiguration(
            diskImagePath: URL(fileURLWithPath: "/dev/null"),
            macAddress: .randomLocallyAdministered()
        )

        XCTAssertEqual(configuration.calculateMemorySize(
            min: min,
            max: max,
            hostReserved: hostReservedRAM,
            shared: true
        ), 15_032_385_536)
    }
}
