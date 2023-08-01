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
    func lookupImage(named name: String) async throws -> VM?
    func download(
        image: VM,
        destinationDirectory: URL,
        progressCallback: @escaping FileTransferProgressCallback
    ) async throws -> URL

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
        guard try await S3Server.vmImages.hasFile(at: "manifest.txt") else {
            throw RemoteVMLibraryErrors.manifestNotFound
        }

        let bytes = try await S3Server.vmImages.fetchFileBytes(forFileAt: "manifest.txt")

        guard let manifestString = String(data: bytes, encoding: .utf8) else {
            throw RemoteVMLibraryErrors.invalidManifest
        }

        return manifestString
            .split(separator: "\n")
            .map { String($0) }
    }

    func download(
        image: VM,
        destinationDirectory: URL,
        progressCallback: @escaping FileTransferProgressCallback
    ) async throws -> URL {

        for server in servers {
            guard try await server.hasFile(at: image.path) else {
                continue
            }

            let destination = destinationDirectory.appendingPathComponent(image.fileName)

            try await server.downloadFile(
                at: image.path,
                to: destination,
                progress: progressCallback
            )

            return destination
        }

        throw RemoteVMLibraryErrors.vmNotFound
    }


    public func listImages(sortedBy strategy: RemoteVMImageSortingStrategy = .name) async throws -> [VM] {
        let objects = try await S3Server.vmImages.listFiles(startingWith: "images/")
        return remoteImagesFrom(objects: objects)
    }

    public func lookupImage(named name: String) async throws -> (VM)? {
        try await listImages().first(where: { $0.name == name })
    }

    public func remoteImagesFrom(objects: [RemoteFile]) -> [VM] {
        objects.compactMap(VM.init)
    }
}
