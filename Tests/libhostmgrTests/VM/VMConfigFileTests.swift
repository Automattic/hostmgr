import XCTest
import Virtualization
@testable import libhostmgr

final class VMConfigFileTests: XCTestCase {

    let sampleConfig1 = pathForResource(named: "vm-config-file-sample-1.json")
    let sampleConfig2 = pathForResource(named: "vm-config-file-sample-2.json")
    let sampleConfig3 = pathForResource(named: "vm-config-file-sample-3.json")

    func testThatConfigFileCanBeParsed() throws {
        XCTAssertNotNil(try VMConfigFile.from(url: sampleConfig1))
        XCTAssertNotNil(try VMConfigFile.from(url: sampleConfig2))
        XCTAssertNotNil(try VMConfigFile.from(url: sampleConfig3))
    }

    func testThatNameIsParsedCorrectly() throws {
        XCTAssertNil(try configFileSample1.name)
        XCTAssertEqual(try configFileSample2.name, "sample-2")
        XCTAssertNil(try configFileSample3.name)
    }

    func testThatTemplateNameIsParsedCorrectly() throws {
        XCTAssertNil(try configFileSample1.templateName)
        XCTAssertNil(try configFileSample2.templateName)
        XCTAssertEqual(try configFileSample3.templateName, "sample-3")
    }

    func testThatHardwareModelIsParsedCorrectly() throws {
        XCTAssert(
            try configFileSample1.hardwareModel.dataRepresentation,
            hasHash: "3aTbdKrJ+27C8JaCzSmHNr32t5IbeuA5VjC48XCcGu8="
        )
    }

    func testThatMachineIdentifierIsParsedCorrectly() throws {
        XCTAssert(
            try configFileSample1.machineIdentifier.dataRepresentation,
            hasHash: "0DXW7UIFta6W86ZZd24QUy4Gx3EX1+r9i+yYk7xHi0s="
        )
    }

    func testThatMacAddressIsParsedCorrectly() throws {
        XCTAssertEqual(try configFileSample1.macAddress.string, "86:ca:72:9b:6a:57")
    }

    func testThatSettingUniqueMacAddressUpdatesCorrectly() throws {
        let newAddress = VZMACAddress.randomLocallyAdministered()
        let newObject = try configFileSample1.settingUniqueMacAddress(to: newAddress)
        XCTAssertEqual(newObject.macAddress.string, newAddress.string)
    }

    func testThatSettingUniqueMacAddressPersistsTemplateName() throws {
        try XCTAssertEqual(configFileSample3.templateName, configFileSample3.settingUniqueMacAddress().templateName)
    }

    func testThatSettingUniqueMachineIdentifierUpdatesCorrectly() throws {
        let newIdentifier = VZMacMachineIdentifier()
        let newObject = try configFileSample1.settingUniqueMachineIdentifier(to: newIdentifier)
        XCTAssertEqual(newObject.machineIdentifier, newIdentifier)
    }

    func testThatSettingUniqueMachineIdentifierPersistsTemplateName() throws {
        try XCTAssertEqual(
            configFileSample3.templateName,
            configFileSample3.settingUniqueMachineIdentifier().templateName
        )
    }

    func testThatSettingTemplateNameUpdatesCorrectly() throws {
        let templateName = "my-template-name"
        let newObject = try configFileSample1.settingTemplateName(to: templateName)
        XCTAssertEqual(newObject.templateName, templateName)
    }

    func testThatRoundTripEncodingProducesCorrectResult() throws {
        try XCTAssertEqual(configFileSample1, roundTrip(configFileSample1))
        try XCTAssertEqual(configFileSample2, roundTrip(configFileSample2))
        try XCTAssertEqual(configFileSample3, roundTrip(configFileSample3))
    }

    func testThatParserThrowsForInvalidHardwareModel() throws {
        XCTAssertThrowsError(try VMConfigFile.Parse.hardwareModel(data: Data()))
    }

    func testThatParserThrowsForInvalidMachineIdentifier() throws {
        XCTAssertThrowsError(try VMConfigFile.Parse.machineIdentifier(data: Data()))
    }

    func testThatParserThrowsForInvalidMacAddress() throws {
        XCTAssertThrowsError(try VMConfigFile.Parse.macAddress(string: ""))
    }

    /// Configuration file with no `name` or `vmTemplate` fields set
    ///
    var configFileSample1: VMConfigFile {
        get throws {
            try VMConfigFile.from(url: sampleConfig1)
        }
    }

    /// Configuration file with `name` set, but not `vmTemplate`
    ///
    var configFileSample2: VMConfigFile {
        get throws {
            try VMConfigFile.from(url: sampleConfig2)
        }
    }

    /// Configuration file with `vmTemplate` set, but not `name`
    ///
    var configFileSample3: VMConfigFile {
        get throws {
            try VMConfigFile.from(url: sampleConfig3)
        }
    }

    func roundTrip<T>(_ object: T) throws -> T where T: Codable {
        let encoded = try JSONEncoder().encode(object)
        return try JSONDecoder().decode(T.self, from: encoded)
    }
}
