import Foundation
import Network
import Virtualization

public struct VMBundle: Sendable {
    public let root: URL

    private let config: VMConfigFile

    public init(at root: URL) throws {
        self.root = root
        self.config = try VMConfigFile.from(url: Self.configurationFilePath(for: self.root))
    }
}

extension VMBundle: Bundle {

    var hardwareModel: VZMacHardwareModel {
        config.hardwareModel
    }

    var machineIdentifier: VZMacMachineIdentifier {
        config.machineIdentifier
    }

    var macAddress: VZMACAddress {
        config.macAddress
    }

    /// The name of the template that this bundle was created from
    ///
    /// If this bundle wasn't created from a template, this field is `nil`
    var templateName: String? {
        config.templateName
    }

    /// The path to this bundle if it were converted into a template
    ///
    var derivedTemplatePath: URL {
        root.deletingPathExtension().appendingPathExtension("vmtemplate")
    }

    func set(config: VMConfigFile) throws {
        try config.write(to: self.configurationFilePath)
    }

    /// Look up details of this VM's most recent DHCP lease.
    ///
    /// Note that there's no guarantee that the IP address associated with this lease
    /// is valid unless the VM is currently booted
    public var currentDHCPLease: DHCPLease? {
        get throws {
            try DHCPLease.mostRecentLease(forMACaddress: self.macAddress)
        }
    }

    /// Update a cloned VMBundle to record its new name and have a unique MAC address
    ///
    @discardableResult
    public func preparedForReuse() throws -> VMBundle {
        let newBundle = try VMBundle(at: self.root)

        try newBundle.config
            .settingUniqueMacAddress()
            .settingUniqueMachineIdentifier()
            .settingTemplateName(to: self.config.name)
            .write(to: newBundle.configurationFilePath)

        return newBundle
    }

    /// Create a new VMBundle based on a restore image
    ///
    public static func createBundle(
        named name: String,
        fromRestoreImage image: VZMacOSRestoreImage,
        withStorageCapacity capacity: Measurement<UnitInformationStorage>
    ) throws -> VMBundle {
        guard let macOSConfiguration = image.mostFeaturefulSupportedConfiguration else {
            throw HostmgrError.invalidVMSourceImage(image.url)
        }

        Console.log("Loaded VM Configuration from Restore Image")

        let bundleRoot = Paths.vmImageStorageDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("bundle")

        try FileManager.default.createDirectory(at: bundleRoot, withIntermediateDirectories: true)
        Console.success("Created bundle at \(bundleRoot.path)")

        let bundle = try VMBundle(at: bundleRoot)

        let configFile = VMConfigFile(
            name: name,
            hardwareModel: macOSConfiguration.hardwareModel,
            machineIdentifier: VZMacMachineIdentifier(),
            macAddress: .randomLocallyAdministered()
        )

        try bundle.set(config: configFile)
        try bundle.initializeStorageVolume(withSize: capacity)

        return bundle
    }

    /// Reserves the required local disk space for the VM disk image
    ///
    private func initializeStorageVolume(withSize size: Measurement<UnitInformationStorage>) throws {
        guard !FileManager.default.fileExists(at: self.diskImageFilePath) else {
            return
        }

        try FileManager.default.createEmptyFile(at: self.diskImageFilePath, size: size)
    }

    public func virtualMachineConfiguration() throws -> VZVirtualMachineConfiguration {
        let configuration = try VMConfiguration(
            diskImagePath: self.diskImageFilePath,
            macAddress: self.macAddress
        ).asVirtualMachineConfiguration
        configuration.platform = try macPlatformConfiguration()
        return configuration
    }

    private func macPlatformConfiguration() throws -> VZMacPlatformConfiguration {
        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = self.hardwareModel
        platform.machineIdentifier = self.machineIdentifier
        platform.auxiliaryStorage = try auxilaryStorage(for: self.hardwareModel)
        return platform
    }

    private func auxilaryStorage(for model: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        guard !FileManager.default.fileExists(at: self.auxImageFilePath) else {
            return VZMacAuxiliaryStorage(url: self.auxImageFilePath)
        }

        return try VZMacAuxiliaryStorage(
            creatingStorageAt: self.auxImageFilePath,
            hardwareModel: model
        )
    }
}
