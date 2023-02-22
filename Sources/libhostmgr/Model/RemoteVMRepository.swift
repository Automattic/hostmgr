import Foundation
import tinys3

public struct RemoteVMRepository {

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

    public init(s3Manager: S3ManagerProtocol? = nil) throws {
        let bucket: String = Configuration.shared.vmImagesBucket
        let region: String = Configuration.shared.vmImagesRegion
        let credentials = try AWSCredentials.fromUserConfiguration()

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

    public func getCompatibleImage(named name: String) async throws -> RemoteVMImage? {
        try await listCompatibleImages().first(where: { $0.basename == name })
    }

    /// Downloads a remote image using atomic writes to avoid conflict with existing files or other processes
    ///
    public func download(
        image: RemoteVMImage,
        destinationDirectory: URL,
        progressCallback: @escaping FileTransferProgressCallback
    ) async throws -> URL {

        if image.architecture == .x64 {
            // Download the checksum file first
           try await self.s3Manager.download(
                key: image.checksumObject.key,
                to: destinationDirectory.appendingPathComponent(image.checksumFileName),
                progressCallback: nil)
        }

        let imageFileDestination = destinationDirectory.appendingPathComponent(image.fileName)

        try await self.s3Manager.download(
            key: image.imageObject.key,
            to: imageFileDestination,
            progressCallback: progressCallback
        )

        return imageFileDestination
    }

    public func listCompatibleImages(sortedBy strategy: RemoteVMImageSortingStrategy = .name) async throws -> [RemoteVMImage] {
        let objects = try await self.s3Manager.listObjects(startingWith: "images/")
        let images = remoteImagesFrom(objects: objects)

        #if arch(arm64)
        return images.filter { $0.architecture == .arm64 }
        #else
        return images.filter { $0.architecture == .x64 }
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
}
