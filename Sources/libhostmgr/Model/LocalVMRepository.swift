import Foundation

public enum LocalVMImageSortingStrategy {
    case name
    case size

    var sortMethod: (LocalVMImage, LocalVMImage) throws -> Bool {
        switch self {
        case .name: return sortByName
        case .size: return sortBySize
        }
    }

    func sortByName(_ lhs: LocalVMImage, _ rhs: LocalVMImage) -> Bool {
        lhs.filename.compare(rhs.filename, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
    }

    func sortBySize(_ lhs: LocalVMImage, _ rhs: LocalVMImage) throws -> Bool {
        try lhs.fileSize < rhs.fileSize
    }
}

public protocol LocalVMRepositoryProtocol {
    func list(sortedBy strategy: LocalVMImageSortingStrategy) throws -> [LocalVMImage]
}

public struct LocalVMRepository: LocalVMRepositoryProtocol {

    private let imageDirectory: URL
    private let fileManager: FileManager

    public init(imageDirectory: URL = Configuration.shared.vmStorageDirectory, fileManager: FileManager = .default) {
        self.imageDirectory = imageDirectory
        self.fileManager = fileManager
    }

    /// A list of VM images present on disk
    public func list(sortedBy strategy: LocalVMImageSortingStrategy = .name) throws -> [LocalVMImage] {
        guard try fileManager.directoryExists(at: imageDirectory) else {
            return []
        }

        return try fileManager
            .contentsOfDirectory(atPath: imageDirectory.path)
            .map { URL(fileURLWithPath: $0, relativeTo: self.imageDirectory) }
            .compactMap(LocalVMImage.init)
            .sorted(by: strategy.sortMethod)
    }

    public func lookupVM(withName name: String) throws -> LocalVMImage? {
        try list().first { $0.basename == name }
    }

    /// Delete a list of VM images from the local disk by image name
    public func delete(images: [LocalVMImage]) throws {
        try images.forEach(self.delete)
    }

    /// Delete a single VM image from the local disk by image name
    public func delete(image: LocalVMImage) throws {
        try self.fileManager.removeItem(at: image.path)
    }
}
