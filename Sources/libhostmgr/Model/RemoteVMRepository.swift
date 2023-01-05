import Foundation

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
            lhs.imageObject.modifiedAt > rhs.imageObject.modifiedAt
        }
    }

    private let s3Manager: S3ManagerProtocol

    public init(s3Manager: S3ManagerProtocol? = nil) {
        let bucket: String = Configuration.shared.vmImagesBucket
        let region: String = Configuration.shared.vmImagesRegion

        self.s3Manager = s3Manager ?? S3Manager(bucket: bucket, region: region)
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
    @discardableResult
    public func download(
        image: RemoteVMImage,
        progressCallback: @escaping FileTransferProgressCallback,
        destinationDirectory: URL
    ) async throws -> URL {

        // Download the checksum file first
        _ = try await self.s3Manager.download(
            object: image.checksumObject,
            to: destinationDirectory.appendingPathComponent(image.checksumFileName),
            progressCallback: nil
        )

        return try await self.s3Manager.download(
            object: image.imageObject,
            to: destinationDirectory.appendingPathComponent(image.fileName),
            progressCallback: progressCallback
        )
    }

    public func listImages(sortedBy strategy: RemoteVMImageSortingStrategy = .name) async throws -> [RemoteVMImage] {
        let objects = try await self.s3Manager.listObjects(startingWith: "images/")
        return remoteImagesFrom(objects: objects).sorted(by: strategy.sortMethod)
    }

    func remoteImagesFrom(objects: [S3Object]) -> [RemoteVMImage] {
        let imageObjects = objects
            .filter { $0.key.hasSuffix(".pvmp") }

        let checksums = objects
            .filter { $0.key.hasSuffix(".sha256.txt") }
            .map(\.key)

        return imageObjects.compactMap { object in
            let filename = URL(fileURLWithPath: object.key).lastPathComponent  // filename = my-image.pvmp
            let basename = (filename as NSString).deletingPathExtension        // basename = my-image

            let checksumKey = "images/" + basename + ".sha256.txt"

            guard checksums.contains(checksumKey) else {
                return nil
            }

            return RemoteVMImage(imageObject: object, checksumKey: checksumKey)
        }
    }
}
