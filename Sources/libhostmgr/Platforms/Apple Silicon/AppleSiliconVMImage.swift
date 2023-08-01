import Foundation

public struct AppleSiliconVMImage: LocalVMImage {

    public let path: URL

    public init?(path: URL) {
        self.path = path
    }

    public var state: VMImageState {
        .ready
    }

    public var name: String {
        path.deletingPathExtension().deletingPathExtension().lastPathComponent
    }

    var fileName: String {
        path.lastPathComponent
    }

    public var fileSize: Int {
        get throws {
            try FileManager.default.size(ofObjectAt: path)
        }
    }
}
