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

public actor LocalVMRepository {

    let imageDirectory: URL
    let fileManager: FileManager = FileManager()

    public static let shared = LocalVMRepository()

    init(imageDirectory: URL = Configuration.shared.vmStorageDirectory) {
        self.imageDirectory = imageDirectory
    }

    /// A list of VM images present on disk
    public func list(sortedBy strategy: LocalVMImageSortingStrategy = .name) throws -> [LocalVMImage] {
        guard self.fileManager.directoryExists(at: imageDirectory) else {
            return []
        }

        return try self.fileManager
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
