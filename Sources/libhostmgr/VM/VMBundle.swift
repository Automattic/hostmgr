import Foundation
import Network
import Virtualization
import TSCBasic

public struct VMBundle {

    enum Errors: Error {
        /// We couldn't create the disk image – usually because there were no file descriptors available
        case unableToCreateDiskImage

        /// We couldn't create the disk image – probably because there isn't enough space available on disk
        case unableToProvisionDiskSpace

        /// We created the disk image successfully, but couldn't properly close the file descriptor.
        /// The disk image is probably fine, but you should really try creating it again.
        case unableToCloseDiskImage
    }

    #if arch(arm64)
    struct ConfigFile: Codable {
        let name: String?
        let hardwareModelData: Data
        let machineIdentifierData: Data
        let macAddress: String

        var hardwareModel: VZMacHardwareModel {
            VZMacHardwareModel(dataRepresentation: hardwareModelData)!
        }

        var machineIdentifier: VZMacMachineIdentifier {
            VZMacMachineIdentifier(dataRepresentation: machineIdentifierData)!
        }

        func write(to url: URL) throws {
            try JSONEncoder().encode(self).write(to: url, options: .atomic)
        }

        static func from(url: URL) throws -> ConfigFile {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ConfigFile.self, from: data)
        }
    }

    private let hardwareModel: VZMacHardwareModel
    private let machineIdentifier: VZMacMachineIdentifier
    public let macAddress: VZMACAddress
    #endif

    public let root: URL
    public let templateName: String?

    var name: String {
        self.root.deletingPathExtension().lastPathComponent
    }
}

#if arch(arm64)
extension VMBundle: Bundle {

    init(
        root: URL,
        hardwareModel: VZMacHardwareModel,
        machineIdentifier: VZMacMachineIdentifier,
        macAddress: VZMACAddress,
        templateName: String? = nil
    ) {
        self.root = root
        self.hardwareModel = hardwareModel
        self.machineIdentifier = machineIdentifier
        self.macAddress = macAddress
        self.templateName = templateName
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

    /// Persist the VM configuration to the local disk
    func saveConfiguration() throws {
        try ConfigFile(
            name: self.root.deletingPathExtension().lastPathComponent,
            hardwareModelData: self.hardwareModel.dataRepresentation,
            machineIdentifierData: self.machineIdentifier.dataRepresentation,
            macAddress: self.macAddress.string
        )
        .write(to: self.configurationFilePath)
    }

    /// Instantiate a VMBundle from an existing VM package
    ///
    public static func fromExistingBundle(at url: URL) throws -> VMBundle {
        let configuration = try ConfigFile.from(url: Self.configurationFilePath(for: url))

        guard let macAddress = VZMACAddress(string: configuration.macAddress) else {
            throw CocoaError(.coderInvalidValue)
        }

        return VMBundle(
            root: url,
            hardwareModel: configuration.hardwareModel,
            machineIdentifier: configuration.machineIdentifier,
            macAddress: macAddress,
            templateName: configuration.name
        )
    }

    /// Update a cloned VMBundle to record its new name and have a unique MAC address
    ///
    @discardableResult
    public static func renamingClonedBundle(at url: URL, to name: String) throws -> VMBundle {
        let oldBundle = try fromExistingBundle(at: url)

        let bundle = VMBundle(
            root: oldBundle.root,
            hardwareModel: oldBundle.hardwareModel,
            machineIdentifier: oldBundle.machineIdentifier,
            macAddress: .randomLocallyAdministered(),
            templateName: oldBundle.templateName
        )

        try bundle.saveConfiguration()

        return bundle
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

        let bundle = VMBundle(
            root: bundleRoot,
            hardwareModel: macOSConfiguration.hardwareModel,
            machineIdentifier: VZMacMachineIdentifier(),
            macAddress: .randomLocallyAdministered()
        )

        try bundle.initializeStorageVolume(withSize: capacity)
        try bundle.saveConfiguration()

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
        platform.hardwareModel = self.hardwareModel
        platform.machineIdentifier = self.machineIdentifier
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
#endif
