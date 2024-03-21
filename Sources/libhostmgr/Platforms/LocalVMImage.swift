import Foundation

public struct LocalVMImage: Equatable {
    public let path: URL

    public static let validVMExtensions = [
        ".bundle",
        ".vmtemplate",
        ".vmtemplate.aar"
    ]

    public init?(path: URL) {
        guard Self.validVMExtensions.contains(where: { path.path.hasSuffix($0) }) else {
            return nil
        }

        self.path = path
    }

    public var state: VMImageState {
        if self.path.pathComponents.starts(with: Paths.vmWorkingStorageDirectory.pathComponents) {
            return .running
        }

        if path.path.hasSuffix(".vmtemplate") {
            return .ready
        }

        if path.path.hasSuffix(".vmtemplate.aar") {
            return .packaged
        }

        if path.path.hasSuffix(".bundle") {
            return .ready
        }

        preconditionFailure("Invalid VM State")
    }

    public var name: String {
        if path.path.hasSuffix(".vmtemplate") {
            return path.deletingPathExtension().lastPathComponent
        }

        if path.path.hasSuffix(".vmtemplate.aar") {
            return path.deletingPathExtension().deletingPathExtension().lastPathComponent
        }

        return path.deletingPathExtension().lastPathComponent
    }

    public var fileSize: Int {
        get throws {
            try FileManager.default.size(ofObjectAt: path)
        }
    }
}

public enum VMImageState: String, CaseIterable {
    case packaged = "📦 Packaged"
    case ready = "💾 Ready"
    case running = "🟢 Running"
}
