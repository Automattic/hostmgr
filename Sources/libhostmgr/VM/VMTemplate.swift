import Foundation
import Virtualization

public struct VMTemplate: TemplateBundle {
    let root: URL

    struct ManifestFile: Equatable, Codable {
        let imageHash: Data
        let auxilaryDataHash: Data

        func write(to url: URL) throws {
            try JSONEncoder().encode(self).write(to: url, options: .atomic)
        }

        static func from(url: URL) throws -> ManifestFile? {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ManifestFile.self, from: data)
        }
    }

    init(at url: URL) {
        self.root = url
    }

    public var basename: String {
        self.root.lastPathComponent
    }

    public var macAddress: VZMACAddress {
        get throws {
            return try VMBundle(at: self.root).macAddress
        }
    }

    @discardableResult
    public func compress() throws -> Self {
        let fileName = self.root.deletingPathExtension().lastPathComponent
        let destination = self.root.deletingLastPathComponent()
            .appendingPathComponent(fileName)
            .appendingPathExtension("vmtemplate")
            .appendingPathExtension("aar")

        try Compressor.compress(directory: self.root, to: destination)

        return self
    }

    func hashDiskImage() throws -> Data {
        try FileHasher.hash(fileAt: self.diskImageFilePath)
    }

    func hashAuxData() throws -> Data {
        try FileHasher.hash(fileAt: self.auxImageFilePath)
    }

    /// Seals this VM template against future modification by:
    ///
    ///  - Calculating and recording a disk image hash
    ///  - Calculating and recording an auxilary data hash
    ///
    ///  This method also re-applies the `bundle` bit on template's source directory if it's missing – the bundle
    ///  isn't valid without it, but we can fix it transparently
    ///
    @discardableResult
    public func seal() throws -> Self {
        try ManifestFile(
            imageHash: try self.hashDiskImage(),
            auxilaryDataHash: try self.hashAuxData()
        ).write(to: self.manifestFilePath)

        return try self.applyingBundleBit()
    }

    /// Validate this VM template by:
    ///
    ///  - Ensuring that the manifest is present and can be parsed
    ///  - Ensuring that the disk image has not been modified
    ///  - Ensuring that the auxiliary data image has not been modified
    ///  - Ensuring that the configuration file is present
    ///
    ///  This method also re-applies the `bundle` bit on template's source directory if it's missing – the bundle
    ///  isn't valid without it, but we can fix it transparently
    @discardableResult
    public func validate() throws -> Self {

        guard FileManager.default.fileExists(at: manifestFilePath) else {
            throw HostmgrError.vmManifestFileNotFound(manifestFilePath)
        }

        guard let manifest = try ManifestFile.from(url: manifestFilePath) else {
            throw HostmgrError.vmManifestFileInvalid(manifestFilePath)
        }

        guard try manifest.imageHash == hashDiskImage() else {
            throw HostmgrError.vmDiskImageCorrupt(root)
        }

        guard try manifest.auxilaryDataHash == hashAuxData() else {
            throw HostmgrError.vmAuxDataCorrupt(root)
        }

        guard FileManager.default.fileExists(at: configurationFilePath) else {
            throw HostmgrError.vmConfigurationFileMissing(configurationFilePath)
        }

        /// Ensure that the bundle bit is applied
        return try self.applyingBundleBit()
    }

    /// Create a read-only template on disk from an existing VM bundle
    public static func creatingTemplate(fromBundle bundle: VMBundle) throws -> VMTemplate {

        let template = VMTemplate(at: bundle.derivedTemplatePath)

        guard try !FileManager.default.directoryExists(at: template.root) else {
            throw CocoaError(.fileWriteFileExists)
        }

        try FileManager.default.createDirectory(at: template.root, withIntermediateDirectories: true)

        try FileManager.default.copyItem(at: bundle.configurationFilePath, to: template.configurationFilePath)
        try FileManager.default.copyItem(at: bundle.auxImageFilePath, to: template.auxImageFilePath)
        try FileManager.default.copyItem(at: bundle.diskImageFilePath, to: template.diskImageFilePath)

        return try template.seal()
    }

    func applyingBundleBit() throws -> Self {
        try FileManager.default.setBundleBit(forDirectoryAt: self.root, to: true)
        return self
    }
}
