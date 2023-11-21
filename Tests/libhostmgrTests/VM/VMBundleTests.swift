import XCTest
@testable import libhostmgr
import Virtualization

final class VMBundleTests: XCTestCase {

    func testThatMacAddressIsRotatedInBundle() throws {
        let originalBundle = try VMBundle.forTesting()
        let newBundle = try originalBundle.createEphemeralCopy(at: VMBundle.createRoot())
        XCTAssertNotEqual(originalBundle.macAddress, newBundle.macAddress)
    }
}

extension VMBundle {

    static func createRoot() -> URL {
        URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    static func forTesting() throws -> VMBundle {
        let bundleRoot = createRoot()
        let configFilePath = bundleRoot.appendingPathComponent("config.json")

        try VMConfigFile(
            name: "foo",
            hardwareModel: try .testDefault,
            machineIdentifier: VZMacMachineIdentifier(),
            macAddress: .randomLocallyAdministered()
        ).write(to: configFilePath)

        return try VMBundle(at: bundleRoot)
    }
}
