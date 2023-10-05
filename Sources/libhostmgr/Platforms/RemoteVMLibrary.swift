import Foundation
import tinys3

public enum RemoteVMImageSortingStrategy {
    case name
    case size
    case newest

    var sortMethod: (any RemoteVMImage, any RemoteVMImage) -> Bool {
        switch self {
        case .name: return sortByName
        case .size: return sortBySize
        case .newest: return sortByDateDescending
        }
    }

    func sortByName(_ lhs: any RemoteVMImage, _ rhs: any RemoteVMImage) -> Bool {
        lhs.fileName.compare(rhs.fileName, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
    }

    func sortBySize(_ lhs: any RemoteVMImage, _ rhs: any RemoteVMImage) -> Bool {
        lhs.size < rhs.size
    }

    func sortByDateDescending(_ lhs: any RemoteVMImage, _ rhs: any RemoteVMImage) -> Bool {
        lhs.lastModifiedAt > rhs.lastModifiedAt
    }
}

public protocol RemoteVMLibrary<VM> {

    associatedtype VM: RemoteVMImage

    func getManifest() async throws -> [String]
    func listImages(sortedBy strategy: RemoteVMImageSortingStrategy) async throws -> [VM]
    func hasImage(named: String) async throws -> Bool
    func lookupImage(named name: String) async throws -> VM

    @discardableResult
    func download(vmNamed: String, progressCallback: @escaping ProgressCallback) async throws -> URL

    /// Make a local image available for others to use (by publishing it to S3)
    ///
    /// This method is the preferred way to deploy a VM image
    func publish(vmNamed: String, progressCallback: @escaping ProgressCallback) async throws

    func remoteImagesFrom(objects: [RemoteFile]) -> [VM]
}

enum RemoteVMLibraryErrors: Error {
    case vmNotFound
    case manifestNotFound
    case invalidManifest
}

extension RemoteVMLibrary {

    var servers: [ReadOnlyRemoteFileProvider] {
        [
            CacheServer.vmImages,
            S3Server.vmImages
        ]
    }

    public func getManifest() async throws -> [String] {
        let objects = try await S3Server.vmImages.listFiles(startingWith: "/images/")
        return remoteImagesFrom(objects: objects).map { $0.name }
    }

    public func download(vmNamed name: String, progressCallback: @escaping ProgressCallback) async throws -> URL {
        let image = try await lookupImage(named: name)

        // If this is the first run, the storage directory may not exist, so we'll create it just in case
        try FileManager.default.createDirectory(at: Paths.vmImageStorageDirectory, withIntermediateDirectories: true)

        let availableStorageSpace = try FileManager.default.availableStorageSpace(
            forVolumeContainingDirectoryAt: Paths.vmImageStorageDirectory
        )

        guard image.size < availableStorageSpace else {
            throw HostmgrError.notEnoughLocalDiskSpaceToDownloadFile(image.fileName, image.size, availableStorageSpace)
        }

        guard let server = try await servers.first(havingFileAtPath: image.path) else {
            throw RemoteVMLibraryErrors.vmNotFound
        }

        let destination = Paths.vmImageStorageDirectory.appendingPathComponent(image.fileName)

        try await server.downloadFile(
            at: image.path,
            to: destination,
            progress: progressCallback
        )

        return destination
    }

    public func listImages(sortedBy strategy: RemoteVMImageSortingStrategy = .name) async throws -> [VM] {
        let objects = try await S3Server.vmImages.listFiles(startingWith: "images/")
        return remoteImagesFrom(objects: objects)
    }

    public func hasImage(named name: String) async throws -> Bool {
        try await listImages().contains(where: { $0.name == name })
    }

    public func lookupImage(named name: String) async throws -> VM {
        guard let image = try await listImages().first(where: { $0.name == name }) else {
            throw HostmgrError.unableToFindRemoteImage(name)
        }

        return image
    }

    public func remoteImagesFrom(objects: [RemoteFile]) -> [VM] {
        objects.compactMap(VM.init)
    }

    public func publish(vmNamed name: String, progressCallback: @escaping ProgressCallback) async throws {
        try await S3Server.vmImages.uploadFile(
            at: Paths.toArchivedVM(named: name),
            to: "/images/" + Paths.toArchivedVM(named: name).lastPathComponent,
            progress: progressCallback
        )
    }
}
