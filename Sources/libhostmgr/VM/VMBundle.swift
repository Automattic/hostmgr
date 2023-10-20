import Foundation
import Network
import Virtualization
import TSCBasic

public struct VMBundle: Sendable {

    enum Errors: Error {
        /// We couldn't create the disk image – usually because there were no file descriptors available
        case unableToCreateDiskImage

        /// We couldn't create the disk image – probably because there isn't enough space available on disk
        case unableToProvisionDiskSpace

        /// We created the disk image successfully, but couldn't properly close the file descriptor.
        /// The disk image is probably fine, but you should really try creating it again.
        case unableToCloseDiskImage
    }

    public let root: URL

    public init(at root: URL) {
        self.root = root
    }
}

extension VMBundle: Bundle {

    var hardwareModel: VZMacHardwareModel {
        get throws {
            try getConfig().hardwareModel
        }
    }

    var machineIdentifier: VZMacMachineIdentifier {
        get throws {
            try getConfig().machineIdentifier
        }
    }

    var macAddress: VZMACAddress {
        get throws {
            try getConfig().macAddress
        }
    }

    /// The name of the template that this bundle was created from
    ///
    /// If this bundle wasn't created from a template, this field is `nil`
    var templateName: String? {
        get throws {
            try getConfig().templateName
        }
    }

    /// The path to this bundle if it were converted into a template
    ///
    var derivedTemplatePath: URL {
        root.deletingPathExtension().appendingPathExtension("vmtemplate")
    }

    func getConfig() throws -> VMConfigFile {
        try VMConfigFile.from(url: Self.configurationFilePath(for: self.root))
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
    public func withRandomizedHardwareAddress() throws -> VMBundle {
        let oldBundle = VMBundle(at: self.root)

        try oldBundle.getConfig()
            .settingUniqueMacAddress()
            .settingUniqueMachineIdentifier()
            .write(to: oldBundle.configurationFilePath)

        return oldBundle
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

        let bundle = VMBundle(at: bundleRoot)

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

        let diskFd = open(self.diskImageFilePath.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)

        guard diskFd != -1 else {
            throw Errors.unableToCreateDiskImage
        }

        guard ftruncate(diskFd, off_t(size.converted(to: .bytes).value)) == 0 else {
            throw Errors.unableToProvisionDiskSpace
        }

        guard close(diskFd) == 0 else {
            throw Errors.unableToCloseDiskImage
        }
    }

    private func macPlatformConfiguration() throws -> VZMacPlatformConfiguration {
        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = try self.hardwareModel
        platform.machineIdentifier = try self.machineIdentifier
        platform.auxiliaryStorage = try auxilaryStorage(for: self.hardwareModel)
        return platform
    }

    public func virtualMachineConfiguration() throws -> VZVirtualMachineConfiguration {
        let configuration = try VMConfiguration(
            diskImagePath: self.diskImageFilePath,
            macAddress: self.macAddress
        ).asVirtualMachineConfiguration
        configuration.platform = try macPlatformConfiguration()
        return configuration
    }

    private func auxilaryStorage(for model: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        guard !FileManager.default.fileExists(at: self.auxImageFilePath) else {
            if #available(macOS 13.0, *) {
                return VZMacAuxiliaryStorage(url: self.auxImageFilePath)
            } else {
                return VZMacAuxiliaryStorage(contentsOf: self.auxImageFilePath)
            }
        }

        return try VZMacAuxiliaryStorage(
            creatingStorageAt: self.auxImageFilePath,
            hardwareModel: model
        )
    }
}
