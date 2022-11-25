import Foundation
import tinys3

public actor RemoteVMRepository {

    public enum RemoteVMImageSortingStrategy {
        case name
        case size
        case newest

        var sortMethod: (RemoteVMImage, RemoteVMImage) -> Bool {
            switch self {
            case .name: return sortByName
            case .size: return sortBySize
            case .newest: return sortByDateDescending
            }
        }

        func sortByName(_ lhs: RemoteVMImage, _ rhs: RemoteVMImage) -> Bool {
            lhs.fileName.compare(rhs.fileName, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
        }

        func sortBySize(_ lhs: RemoteVMImage, _ rhs: RemoteVMImage) -> Bool {
            lhs.imageObject.size < rhs.imageObject.size
        }

        func sortByDateDescending(_ lhs: RemoteVMImage, _ rhs: RemoteVMImage) -> Bool {
            lhs.imageObject.lastModifiedAt > rhs.imageObject.lastModifiedAt
        }
    }

    private let s3Manager: S3ManagerProtocol

    private static var _shared: RemoteVMRepository!

    public static var shared: RemoteVMRepository {
        get throws {
            if _shared == nil {
                _shared = try RemoteVMRepository()
            }

            return _shared
        }
    }

    private init(s3Manager: S3ManagerProtocol? = nil) throws {
        let bucket: String = Configuration.shared.vmImagesBucket
        let region: String = Configuration.shared.vmImagesRegion
        let credentials = try AWSCredentials.fromUserConfiguration()!

        self.s3Manager = try s3Manager ?? S3Manager(
            bucket: bucket,
            region: region,
            credentials: credentials,
            endpoint: .accelerated
        )
    }

    public func getManifest() async throws -> [String] {
        guard
            let object = try await self.s3Manager.lookupObject(atPath: "manifest.txt"),
            let bytes = try await self.s3Manager.download(object: object),
            let manifestString = String(data: bytes, encoding: .utf8)
        else {
            return []
        }

        return manifestString
            .split(separator: "\n")
            .map { String($0) }
    }

    public func getImage(named name: String) async throws -> RemoteVMImage? {
        try await listImages().first(where: { $0.basename == name })
    }

    /// Downloads a remote image using atomic writes to avoid conflict with existing files or other processes
    ///
    public func download(
        image: RemoteVMImage,
        progressCallback: @escaping FileTransferProgressCallback
    ) async throws -> URL {

        let checksumDestination = Configuration.shared.vmStorageDirectory.appendingPathComponent(image.checksumFileName)
        let imageDestination = Configuration.shared.vmStorageDirectory.appendingPathComponent(image.fileName)

        // If we have any already-downloaded files, delete them before starting
        try FileManager.default.deleteFileIfExists(at: checksumDestination)
        try FileManager.default.deleteFileIfExists(at: imageDestination)

        // Download the checksum file first
        _ = try await self.s3Manager.download(
            key: image.checksumObject.key,
            to: checksumDestination,
            progressCallback: nil
        )

        try await self.s3Manager.download(
            key: image.imageObject.key,
            to: imageDestination,
            progressCallback: progressCallback
        )

        return imageDestination
    }

    public func listImages(sortedBy strategy: RemoteVMImageSortingStrategy = .name) async throws -> [RemoteVMImage] {
        let objects = try await self.s3Manager.listObjects(startingWith: "images/")
        return remoteImagesFrom(objects: objects).sorted(by: strategy.sortMethod)
    }

    func remoteImagesFrom(objects: [S3Object]) -> [RemoteVMImage] {
        let imageObjects = objects
            .filter { $0.key.hasSuffix(".pvmp") }
            .sorted()

        let checksums = objects
            .filter { $0.key.hasSuffix(".sha256.txt") }
            .sorted()

        return zip(imageObjects, checksums).reduce(into: [RemoteVMImage]()) {
            $0.append(RemoteVMImage(imageObject: $1.0, checksumObject: $1.1))
        }
    }
}
