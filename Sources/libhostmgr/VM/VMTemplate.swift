import Foundation

@available(macOS 13.0, *)
public struct VMTemplate: TemplateBundle {
    let root: URL

    enum Errors: Error {
        case invalidDiskImageHash
        case invalidAuxImageHash
        case missingConfigFile
        case missingManifest
        case invalidManifest
    }

    struct ManifestFile: Codable {
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

    public init(named name: String) {
        self.root = Paths.toVMTemplate(named: name)
    }

    public init(at url: URL) {
        self.root = url
    }

    @discardableResult
    public func compress() throws -> Self {
        let fileName = self.root.deletingPathExtension().lastPathComponent
        let destination = self.root.deletingLastPathComponent()
            .appending(component: fileName)
            .appendingPathExtension("vmpackage")
            .appendingPathExtension("aar")

        Console.info("Compressing VM Package")
        try Compressor.compress(directory: self.root, to: destination)
        Console.success("Compression Complete")

        return self
    }

    func hashDiskImage() throws -> Data {
        Console.info("Hashing Disk Image")
        let hash: Data = try FileHasher.hash(fileAt: self.diskImageFilePath)
        Console.success("Hashing Disk Image Complete")
        return hash
    }

    func hashAuxData() throws -> Data {
        Console.info("Hashing Aux Data")
        let hash: Data = try FileHasher.hash(fileAt: self.auxImageFilePath)
        Console.success("Hashing Aux Data Complete")
        return hash
    }

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

        return self
    }

    func createManifest() throws {
        try ManifestFile(
            imageHash: try hashDiskImage(),
            auxilaryDataHash: try hashAuxData()
        ).write(to: manifestFilePath)
    }

    public static func creatingTemplate(fromBundle bundle: VMBundle) throws -> VMTemplate {
        let _templateRoot = bundle.root
            .deletingPathExtension()
            .appendingPathExtension("vmpackage")

        let template = VMTemplate(at: _templateRoot)

        guard try !FileManager.default.directoryExists(at: template.root) else {
            throw CocoaError(.fileWriteFileExists)
        }

        try FileManager.default.createDirectory(at: template.root, withIntermediateDirectories: true)
        try FileManager.default.setBundleBit(forDirectoryAt: template.root, to: true)

        try FileManager.default.copyItem(at: bundle.configurationFilePath, to: template.configurationFilePath)
        try FileManager.default.copyItem(at: bundle.auxImageFilePath, to: template.auxImageFilePath)
        try FileManager.default.copyItem(at: bundle.diskImageFilePath, to: template.diskImageFilePath)

        try template.createManifest()

        return template
    }
}
