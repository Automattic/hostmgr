import Foundation
import Network
import Virtualization
import TSCBasic

#if arch(arm64)
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

    struct ConfigFile: Codable {
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

    public let root: URL
    private let hardwareModel: VZMacHardwareModel
    private let machineIdentifier: VZMacMachineIdentifier
    public let macAddress: VZMACAddress

    /// Persist the VM configuration to the local disk
    func saveConfiguration() throws {
        try ConfigFile(
            hardwareModelData: self.hardwareModel.dataRepresentation,
            machineIdentifierData: self.machineIdentifier.dataRepresentation,
            macAddress: self.macAddress.string
        )
        .write(to: self.configurationFilePath)
    }

    var name: String {
        self.root.deletingPathExtension().lastPathComponent
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

    init(
        root: URL,
        hardwareModel: VZMacHardwareModel,
        machineIdentifier: VZMacMachineIdentifier,
        macAddress: VZMACAddress
    ) {
        self.root = root
        self.hardwareModel = hardwareModel
        self.machineIdentifier = machineIdentifier
        self.macAddress = macAddress
    }
}

@available(macOS 11.0, *)
extension VMBundle: Bundle {
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
            macAddress: macAddress
        )
    }

    /// Create a new VMBundle based on a restore image
    ///
    public static func createBundle(
        named name: String,
        fromRestoreImage image: VZMacOSRestoreImage,
        withStorageCapacity capacity: Measurement<UnitInformationStorage>
    ) throws -> VMBundle {
        guard let macOSConfiguration = image.mostFeaturefulSupportedConfiguration else {
            Console.crash(
                message: "This Mac cannot create a VM from the disk image at \(image.url)",
                reason: .fileNotFound
            )
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
