import Foundation
@preconcurrency import Virtualization
import TSCBasic

@available(macOS 13.0, *)
public struct VMBundle: Sendable {
    
    internal struct BundlePathResolver {
        let path: URL
        
        var configurationFilePath: URL {
            self.path.appendingPathComponent("config.json")
        }

        var auxiliaryFileStorage: URL {
            self.path.appendingPathComponent("aux.img")
        }

        var diskImageFilePath: URL {
            self.path.appendingPathComponent("image.img")
        }
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

        static func from(url: URL) throws -> ConfigFile? {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ConfigFile.self, from: data)
        }
    }

    private let root: URL
    private let hardwareModel: VZMacHardwareModel
    private let machineIdentifier: VZMacMachineIdentifier

    /// Persist the VM configuration to the local disk
    func saveConfiguration() throws {
        let pathResolver = BundlePathResolver(path: self.root)

        try ConfigFile(
            hardwareModelData: self.hardwareModel.dataRepresentation,
            machineIdentifierData: self.machineIdentifier.dataRepresentation
        )
        .write(to: pathResolver.configurationFilePath)
    }

    var pathResolver: BundlePathResolver {
        BundlePathResolver(path: self.root)
    }
}

@available(macOS 13.0, *)
extension VMBundle {
    /// Instantiate a VMBundle from an existing VM package
    ///
    public static func fromExistingBundle(at url: URL) throws -> VMBundle {
        let pathResolver = BundlePathResolver(path: url)

        guard let configuration = try ConfigFile.from(url: pathResolver.configurationFilePath) else {
            abort() // TODO :This should throw
        }

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
        guard !FileManager.default.fileExists(at: pathResolver.diskImageFilePath) else {
            return
        }

        let diskFd = open(pathResolver.diskImageFilePath.pathWithSlash, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)

        guard diskFd != -1 else {
            fatalError("Cannot create disk image.") //TODO: This should throw
        }

        guard ftruncate(diskFd, off_t(size.converted(to: .bytes).value)) == 0 else {
            fatalError("ftruncate() failed.")
        }

        guard close(diskFd) == 0 else {
            fatalError("Failed to close the disk image.") //TODO: This should throw
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
        let configuration = try VMConfiguration(diskImagePath: self.pathResolver.diskImageFilePath).asVirtualMachineConfiguration
        configuration.platform = try macPlatformConfiguration()
        return configuration
    }

    private func auxilaryStorage(for model: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        let resolver = BundlePathResolver(path: self.root)
        guard !FileManager.default.fileExists(at: resolver.auxiliaryFileStorage) else {
            return VZMacAuxiliaryStorage(url: resolver.auxiliaryFileStorage)
        }

        return try VZMacAuxiliaryStorage(
            creatingStorageAt: resolver.auxiliaryFileStorage,
            hardwareModel: model
        )
    }
}
