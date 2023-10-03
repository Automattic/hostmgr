import Foundation

public struct ParallelsVMImage: LocalVMImage, FilterableByName {

    public static let validVMExtensions = [
        ".pvm",
        ".pvmp",
    ]

    public let path: URL

    public init?(path: URL) {
        guard Self.validVMExtensions.contains(where: { path.path.hasSuffix($0) }) else {
            return nil
        }

        self.init(path: path)
    }

    public var name: String {
        path.deletingPathExtension().lastPathComponent
    }

    public var state: VMImageState {
        switch path.pathExtension {
            case "pvmp": return .packaged
            case "pvm": return .ready
            default: preconditionFailure("Invalid VM State")
        }
    }

    public var filename: String {
        path.lastPathComponent
    }

    public var fileSize: Int {
        get throws {
            try FileManager.default.size(ofObjectAt: path)
        }
    }
}
