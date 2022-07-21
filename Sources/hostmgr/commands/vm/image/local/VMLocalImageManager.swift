import Foundation
import prlctl
import libhostmgr

struct VMLocalImageManager {

    private let imageDirectory: URL
    private let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.imageDirectory = Configuration.shared.vmStorageDirectory
        self.fileManager = fileManager
    }

    /// A list of VM images present on disk
    func list() throws -> [String] {
        try fileManager
            .contentsOfDirectory(atPath: imageDirectory.path)
    }

    /// A list of paths to VM images on disk
    func listImageFilePaths() throws -> [URL] {
        try fileManager
            .contentsOfDirectory(atPath: imageDirectory.path)
            .map { imageDirectory.appendingPathComponent($0) }
    }

    /// Delete a list of VM images from the local disk by image name
    func delete(images: [String]) throws {
        try images.forEach(self.delete)
    }

    /// Delete a single VM image from the local disk by image name
    func delete(name: String) throws {
        guard let vmPath = try pathToLocalImage(named: name) else {
            return
        }

        try self.fileManager.removeItem(at: vmPath)
    }

    func pathToLocalImage(named name: String) throws -> URL? {
        try listImageFilePaths().first { path in
            FileManager.default.displayName(at: path).starts(with: name)
        }
    }
}
