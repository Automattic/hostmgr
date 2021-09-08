import Foundation
import prlctl

struct VMLocalImageManager {

    private let imageDirectory: URL
    private let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.imageDirectory = Configuration.shared.vmStorageDirectory
        self.fileManager = fileManager
    }

    func list() throws -> [String] {
        try Parallels().lookupAllVMs().map { $0.name }
    }

    func listImageFilePaths() throws -> [URL] {
        try fileManager.contentsOfDirectory(atPath: imageDirectory.path)
            .map { imageDirectory.appendingPathComponent($0) }
    }

    func delete(images: [String]) throws {
        for image in images {
            try delete(name: image)
        }
    }

    func delete(name: String) throws {
        try Parallels().lookupVM(named: name)?.delete()
    }

    func lookupVMsBy(handle: String) throws -> [VMProtocol] {
        return try Parallels().lookupAllVMs().filter { vm in
            return vm.name == handle || vm.uuid == handle
        }
    }

    func lookupVMsBy(prefix: String) throws -> [VMProtocol] {
        return try Parallels().lookupAllVMs().filter { vm in
            return vm.name.hasPrefix(prefix)
        }
    }
}
