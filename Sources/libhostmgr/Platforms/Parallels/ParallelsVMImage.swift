import Foundation

public struct ParallelsVMImage: LocalVMImage, FilterableByName {
    public let path: URL

    public init?(path: URL) {
        self.path = path
    }

    public var name: String {
        path.deletingPathExtension().lastPathComponent
    }

    public var state: VMImageState {
        switch path.pathExtension {
            case "pvmp": return .packaged
            case "pvm": return .ready
            default: Console.crash(message: "Invalid VM: \(self.path)", reason: .invalidVMStatus)
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
