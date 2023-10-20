import Foundation
import Virtualization

struct VMConfigFile: Equatable {

    let name: String?
    let hardwareModel: VZMacHardwareModel
    let machineIdentifier: VZMacMachineIdentifier
    let macAddress: VZMACAddress
    let templateName: String?

    init(
        name: String?,
        hardwareModel: VZMacHardwareModel,
        machineIdentifier: VZMacMachineIdentifier,
        macAddress: VZMACAddress,
        templateName: String? = nil
    ) {
        self.name = name
        self.hardwareModel = hardwareModel
        self.machineIdentifier = machineIdentifier
        self.macAddress = macAddress
        self.templateName = templateName
    }

    static func from(url: URL) throws -> VMConfigFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VMConfigFile.self, from: data)
    }
}

// MARK: Fluent Setters
extension VMConfigFile {
    func settingUniqueMacAddress(to newValue: VZMACAddress = .randomLocallyAdministered()) -> VMConfigFile {
        VMConfigFile(
            name: self.name,
            hardwareModel: self.hardwareModel,
            machineIdentifier: self.machineIdentifier,
            macAddress: newValue,
            templateName: self.templateName
        )
    }

    func settingUniqueMachineIdentifier(
        to newValue: VZMacMachineIdentifier = VZMacMachineIdentifier()
    ) -> VMConfigFile {
        VMConfigFile(
            name: self.name,
            hardwareModel: self.hardwareModel,
            machineIdentifier: newValue,
            macAddress: self.macAddress,
            templateName: self.templateName
        )
    }

    func settingTemplateName(to newValue: String) -> VMConfigFile {
        VMConfigFile(
            name: self.name,
            hardwareModel: self.hardwareModel,
            machineIdentifier: self.machineIdentifier,
            macAddress: self.macAddress,
            templateName: newValue
        )
    }
}

extension VMConfigFile: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case hardwareModel = "hardwareModelData"
        case machineIdentifier = "machineIdentifierData"
        case macAddress
        case templateName
    }

    enum ParsingError: Error {
        case invalidMacAddress
        case invalidHardwareModel
        case invalidMachineIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decodeIfPresent(String.self, forKey: .name)

        let machineIdentifierData = try container.decode(Data.self, forKey: .machineIdentifier)
        self.machineIdentifier = try Parse.machineIdentifier(data: machineIdentifierData)

        let hardwareModelData = try container.decode(Data.self, forKey: .hardwareModel)
        self.hardwareModel = try Parse.hardwareModel(data: hardwareModelData)

        let macAddressString = try container.decode(String.self, forKey: .macAddress)
        self.macAddress = try Parse.macAddress(string: macAddressString)

        self.templateName = try container.decodeIfPresent(String.self, forKey: .templateName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name {
            try container.encode(name, forKey: .name)
        }
        try container.encode(self.hardwareModel.dataRepresentation, forKey: .hardwareModel)
        try container.encode(self.machineIdentifier.dataRepresentation, forKey: .machineIdentifier)
        try container.encode(self.macAddress.string, forKey: .macAddress)

        if let templateName {
            try container.encode(templateName, forKey: .templateName)
        }
    }

    func write(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    struct Parse {
        static func macAddress(string: String) throws -> VZMACAddress {
            guard let address = VZMACAddress(string: string) else {
                throw VMConfigFile.ParsingError.invalidMacAddress
            }

            return address
        }

        static func hardwareModel(data: Data) throws -> VZMacHardwareModel {
            guard let hardwareModel = VZMacHardwareModel(dataRepresentation: data) else {
                throw VMConfigFile.ParsingError.invalidHardwareModel
            }

            return hardwareModel
        }

        static func machineIdentifier(data: Data) throws -> VZMacMachineIdentifier {
            guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: data) else {
                throw VMConfigFile.ParsingError.invalidMachineIdentifier
            }

            return machineIdentifier
        }
    }
}
