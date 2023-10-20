import Foundation
import Virtualization

public struct VMTemplate: TemplateBundle {
    let root: URL

    enum Errors: Error {
        case vmDoesNotExist
        case vmIsNotATemplate

        case invalidDiskImageHash
        case invalidAuxImageHash
        case missingConfigFile
        case missingManifest
        case invalidManifest
    }

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

    var isCompressed: Bool {
        self.root.absoluteString.hasSuffix(".vmtemplate.aar")
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
            throw Errors.missingManifest
        }

        guard let manifest = try ManifestFile.from(url: self.manifestFilePath) else {
            throw Errors.invalidManifest
        }

        guard try manifest.imageHash == hashDiskImage() else {
            throw Errors.invalidDiskImageHash
        }

        guard try manifest.auxilaryDataHash == hashAuxData() else {
            throw Errors.invalidAuxImageHash
        }

        guard FileManager.default.fileExists(at: self.configurationFilePath) else {
            throw Errors.missingConfigFile
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

        try ManifestFile(
            imageHash: try template.hashDiskImage(),
            auxilaryDataHash: try template.hashAuxData()
        ).write(to: template.manifestFilePath)

        return try template.applyingBundleBit()
    }

    func applyingBundleBit() throws -> Self {
        try FileManager.default.setBundleBit(forDirectoryAt: self.root, to: true)
        return self
    }
}
