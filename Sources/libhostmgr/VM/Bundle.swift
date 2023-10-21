import Foundation
import Virtualization
import OSLog

protocol Bundle {
    var root: URL { get }

    var configurationFilePath: URL { get }

    var auxImageFilePath: URL { get }

    var diskImageFilePath: URL { get }
}

extension Bundle {
    var configurationFilePath: URL {
        root.appendingPathComponent("config.json")
    }

    var diskImageFilePath: URL {
        root.appendingPathComponent("image.img")
    }

    var auxImageFilePath: URL {
        root.appendingPathComponent("aux.img")
    }

    static func configurationFilePath(for url: URL) -> URL {
        url.appendingPathComponent("config.json")
    }

    /// Use this template to produce an identical virtual machine at the given `destination`
    ///
    /// Doesn't alter the template in any way, and ensures that each copy has:
    /// - A unique place on the file system.
    /// - A unique MAC address
    ///
    public func createEphemeralCopy(at destination: URL) throws -> VMBundle {
        Logger.helper.log("Creating ephemeral copy of \(root, privacy: .public) at \(destination, privacy: .public)")
        try FileManager.default.createParentDirectoryIfNotExists(for: destination)
        try FileManager.default.copyItem(at: self.root, to: destination)

        return try VMBundle(at: destination).preparedForReuse()
    }
}

protocol TemplateBundle: Bundle {
    var manifestFilePath: URL { get }
}

extension TemplateBundle {
    var manifestFilePath: URL {
        root.appendingPathComponent("manifest.json")
    }
}
