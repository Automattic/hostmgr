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
        let dataRep = try configFileSample1.hardwareModel.dataRepresentation
        // The `dataRepresentation` is supposed to be an opaque value / implementation detail,
        // but that's the only property we have access to and we can thus use for testing correct parsing.
        //
        // This `dataRepresentation` happens to be a binary plist representation of a NSDictionary.
        // We can't just compare the `dataRepresentation` directly with a fixed value though, because different
        // versions of macOS might serialize the exact same NSDictionary as a slightly different NSData representation.
        // Besides, future macOS versions might add additional keys in that internal representation of those objects.
        //
        // So the best we can do is check that the `dataRepresentation` is not nil and check some keys in that dict.
        // This is a bit fragile but at least it's more resilient than comparing the `dataRepresentation` directly.
        let dictRep = try XCTUnwrap(PropertyListSerialization.propertyList(from: dataRep, format: nil) as? NSDictionary)
        XCTAssertEqual(dictRep["MinimumSupportedOS"] as? NSArray, [13, 0, 0])
        XCTAssertEqual(dictRep["PlatformVersion"] as? NSNumber, 2)
    }

    func testThatMachineIdentifierIsParsedCorrectly() throws {
        let dataRep = try configFileSample1.machineIdentifier.dataRepresentation
        // The `dataRepresentation` is supposed to be an opaque value / implementation detail,
        // but that's the only property we have access to and we can thus use for testing correct parsing.
        //
        // This `dataRepresentation` happens to be a binary plist representation of a NSDictionary.
        // We can't just compare the `dataRepresentation` directly with a fixed value though, because different
        // versions of macOS might serialize the exact same NSDictionary as a slightly different NSData representation.
        // Besides, future macOS versions might add additional keys in that internal representation of those objects.
        //
        // So the best we can do is check that the `dataRepresentation` is not nil and check some keys in that dict.
        // This is a bit fragile but at least it's more resilient than comparing the `dataRepresentation` directly.
        let dictRep = try XCTUnwrap(PropertyListSerialization.propertyList(from: dataRep, format: nil) as? NSDictionary)
        XCTAssertNotNil(dictRep["ECID"])
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
