import Foundation
import tinys3

public struct RemoteVMRepository {

    public enum RemoteVMImageSortingStrategy {
        case name
        case size
//        case newest

        var sortMethod: (any RemoteFile, any RemoteFile) -> Bool {
            switch self {
            case .name: return sortByName
            case .size: return sortBySize
//            case .newest: return sortByDateDescending
            }
        }

        func sortByName(_ lhs: any RemoteFile, _ rhs: any RemoteFile) -> Bool {
            lhs.name.compare(rhs.name, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
        }

        func sortBySize(_ lhs: any RemoteFile, _ rhs: any RemoteFile) -> Bool {
            lhs.size < rhs.size
        }

//        func sortByDateDescending(_ lhs: RemoteVMImage, _ rhs: RemoteVMImage) -> Bool {
//            lhs.imageObject.lastModifiedAt > rhs.imageObject.lastModifiedAt
//        }
    }

    let server = S3Server.vmImages

    enum Errors: Error {
        case manifestFileNotFound
        case unableToReadManifestFile
        case imageDoesNotExist
    }

    public init() {}

    public func getManifest() async throws -> [String] {
        guard try await server.hasFile(at: "manifest.txt") else {
            throw Errors.manifestFileNotFound
        }

        let bytes = try await server.fetchFileBytes(forFileAt: "manifest.txt")

        guard let manifestString = String(data: bytes, encoding: .utf8) else {
            throw Errors.unableToReadManifestFile
        }

        return manifestString
            .split(separator: "\n")
            .map { String($0) }
    }

    public func getCompatibleImage(named name: String) async throws -> RemoteVMImage? {
        return nil
//        try await listCompatibleImages().first(where: { $0.basename == name })
    }

    public func getImage(named name: String) async throws -> (any RemoteFile)? {
        try await listImages().first(where: { $0.basename == name })
    }

    /// Downloads a remote image using atomic writes to avoid conflict with existing files or other processes
    ///
    public func download(
        imageNamed name: String,
        destinationDirectory: URL,
        progressCallback: @escaping FileTransferProgressCallback
    ) async throws -> URL {
        let imageFileDestination = destinationDirectory.appendingPathComponent(name)

        // If this is the first run, the storage directory may not exist, so we'll create it just in case
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        #if(arch(x86_64))
        // For some reason (*possibly* due to using `await` with a callback?) downloading the checksum file first
        // breaks the progress bar. Downloading it second resolves this issue 🤷‍♂️
        try await self.s3Manager.download(
            key: image.checksumObject.key,
            to: destinationDirectory.appendingPathComponent(image.checksumFileName),
            replacingExistingFile: false,
            progressCallback: nil
       )
        #else
        guard let image = try await getImage(named: name) else {
            throw Errors.imageDoesNotExist
        }

        try ensureStorageSpaceAvailable(for: image)
        try await server.downloadFile(at: image.path, to: imageFileDestination, progress: progressCallback)
        #endif

        return imageFileDestination
    }

    public func listCompatibleImages(
        sortedBy strategy: RemoteVMImageSortingStrategy = .name
    ) async throws -> [any RemoteFile] {

        return []

        #if arch(arm64)
//        return images.filter { $0.architecture == .arm64 }
        #else
//        return images.filter { $0.architecture == .x64 }
        #endif
    }

    func remoteImagesFrom(objects: [S3Object]) -> [RemoteVMImage] {
        let imageObjects = objects
            .filter { $0.key.hasSuffix(".pvmp") || $0.key.hasSuffix(".vmpackage.aar") }
            .sorted()

        let checksums = objects
            .filter { $0.key.hasSuffix(".sha256.txt") || $0.key.hasSuffix(".vmpackage.aar") }
            .sorted()

        return zip(imageObjects, checksums)
            .map { RemoteVMImage(imageObject: $0, checksumObject: $1) }
    }

    public func listImages(sortedBy strategy: RemoteVMImageSortingStrategy = .name) async throws -> [any RemoteFile] {
        try await server.listFiles(startingWith: "images/")
    }

    func ensureStorageSpaceAvailable(for file: any RemoteFile) throws {
        let availableStorageSpace = try FileManager.default.availableStorageSpace(
            forVolumeContainingDirectoryAt: Paths.vmImageStorageDirectory
        )

        guard file.size < availableStorageSpace else {
            Console.crash(
                message: [
                    "Unable to download \(file.name) (\(Format.fileBytes(file.size)))",
                    "not enough local storage available (\(Format.fileBytes(availableStorageSpace)))"
                ].joined(separator: " - "),
                reason: .notEnoughLocalDiskSpace
            )
        }
    }
}
