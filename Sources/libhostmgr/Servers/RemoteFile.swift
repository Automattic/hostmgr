import Foundation

public struct RemoteFile: Equatable {
    let size: Int
    let path: String
    let lastModifiedAt: Date
}

extension RemoteFile: FilterableByName {
    public var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

extension RemoteFile: FilterableByBasename {
    public var basename: String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}

extension RemoteFile: Comparable {
    public static func < (lhs: RemoteFile, rhs: RemoteFile) -> Bool {
        lhs.path < rhs.path
    }
}