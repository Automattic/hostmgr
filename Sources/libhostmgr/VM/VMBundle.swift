import Foundation
@preconcurrency import Virtualization
import TSCBasic

@available(macOS 13.0, *)
public struct VMBundle: Sendable {

    enum Errors: Error {
        /// We couldn't create the disk image – usually because there were no file descriptors available
        case unableToCreateDiskImage

        /// We couldn't create the disk image – probably because there isn't enough space available on disk
        case unableToProvisionDiskSpace

        /// We created the disk image successfully, but couldn't properly close the file descriptor. The disk image is probably fine, but you should really try creating it again.
        case unableToCloseDiskImage
    }

    struct ConfigFile: Codable {
        let hardwareModelData: Data
        let machineIdentifierData: Data

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

    /// Persist the VM configuration to the local disk
    func saveConfiguration() throws {
        try ConfigFile(
            hardwareModelData: self.hardwareModel.dataRepresentation,
            machineIdentifierData: self.machineIdentifier.dataRepresentation
        )
        .write(to: self.configurationFilePath)
    }

    var name: String {
        self.root.deletingPathExtension().lastPathComponent
    }
}

@available(macOS 13.0, *)
extension VMBundle: Bundle {
    /// Instantiate a VMBundle from an existing VM package
    ///
    public static func fromExistingBundle(at url: URL) throws -> VMBundle {
        let configuration = try ConfigFile.from(url: Self.configurationFilePath(for: url))

        return VMBundle(
            root: url,
            hardwareModel: configuration.hardwareModel,
            machineIdentifier: configuration.machineIdentifier
        )
    }

    /// Create a new VMBundle based on a restore image
    ///
    public static func createBundle(
        named name: String,
        fromRestoreImage image: VZMacOSRestoreImage,
        withStorageCapacity capacity: Measurement<UnitInformationStorage> = .init(value: 64, unit: .gigabytes)
    ) throws -> VMBundle {
        guard let macOSConfiguration = image.mostFeaturefulSupportedConfiguration else {
            Console.crash(
                message: "This Mac cannot create a VM from the disk image at \(image.url)",
                reason: .fileNotFound
            )
        }

        Console.log("Loaded configuration")

        let bundleRoot = Paths.vmImageStorageDirectory
            .appending(path: name)
            .appendingPathExtension("bundle")

        try FileManager.default.createDirectory(at: bundleRoot, withIntermediateDirectories: true)
        Console.log("Created bundle at \(bundleRoot)")

        let bundle = VMBundle(
            root: bundleRoot,
            hardwareModel: macOSConfiguration.hardwareModel,
            machineIdentifier: VZMacMachineIdentifier()
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
        let configuration = try VMConfiguration(diskImagePath: self.diskImageFilePath).asVirtualMachineConfiguration
        configuration.platform = try macPlatformConfiguration()
        return configuration
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
