import Foundation

public struct LocalVMImage: Equatable, FilterableByBasename {

    public enum VMImageState: String, CaseIterable {
        case packaged = "pvmp"
        case ready = "pvm"
    }

    let path: URL

    private static let validVMExtensions = [
        "pvmp", // Packaged VM
        "pvm"   // VM Image
    ]

    public let state: VMImageState

    init?(path: URL) {
        guard let state = VMImageState(rawValue: path.pathExtension) else {
            return nil
        }

        self.path = path
        self.state = state
    }

    public var filename: String {
        path.lastPathComponent
    }

    public var basename: String {
        path.deletingPathExtension().lastPathComponent
    }

    var fileExtension: String {
        path.pathExtension
    }

    public var fileSize: Int {
        get throws {
            try FileManager.default.size(ofObjectAt: path)
        }
    }
}
