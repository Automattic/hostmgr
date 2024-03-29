import Foundation

public struct RemoteFile: Equatable {
    let size: Int
    let path: String
    let lastModifiedAt: Date

    public var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    public var basename: String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}

extension RemoteFile: Comparable {
    public static func < (lhs: RemoteFile, rhs: RemoteFile) -> Bool {
        lhs.path < rhs.path
    }
}
