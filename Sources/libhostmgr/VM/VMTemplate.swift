import Foundation

#if arch(arm64)
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
        return try self.applyBundleBit()
    }

    /// Use this template to produce an identical virtual machine
    ///
    /// Doesn't alter the template in any way, and ensures that each copy has a unique place on the file system.
    /// By default, this method creates the copy in the system temp directory, but the destination can be overridden
    /// using the `url` parameter.
    public func createEphemeralCopy(at url: URL? = nil) throws -> VMBundle {
        let filename = self.root.lastPathComponent + "-" + UUID().uuidString
        let destination = url ?? Paths.ephemeralVMStorageDirectory.appendingPathComponent(filename)

        try Paths.createEphemeralVMStorageIfNeeded()
        try FileManager.default.copyItem(atPath: self.root.path, toPath: destination.path)
        return try VMBundle.fromExistingBundle(at: destination)
    }

    /// Create a read-only template on disk from an existing VM bundle
    public static func creatingTemplate(fromBundle bundle: VMBundle) throws -> VMTemplate {
        let templateRoot = bundle.root
            .deletingPathExtension()
            .appendingPathExtension("vmtemplate")

        let template = VMTemplate(at: templateRoot)

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

        return try template.applyBundleBit()
    }

    public static func existingTemplate(named name: String) throws -> VMTemplate {

        let vmArchivePath = Paths.toArchivedVM(named: name)
        let vmTemplatePath = Paths.toVMTemplate(named: name)

        if FileManager.default.fileExists(at: vmArchivePath) {
            return VMTemplate(at: vmArchivePath)
        }

        if try FileManager.default.directoryExists(at: vmTemplatePath) {
            return VMTemplate(at: vmTemplatePath)
        }

        if try FileManager.default.directoryExists(at: Paths.toAppleSiliconVM(named: name)) {
            throw Errors.vmIsNotATemplate
        }

        throw Errors.vmDoesNotExist
    }

    func applyBundleBit() throws -> Self {
        try FileManager.default.setBundleBit(forDirectoryAt: self.root, to: true)
        return self
    }
}
#endif
