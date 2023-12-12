import Foundation

public struct S3Object: Equatable {
    public let key: String
    public let size: Int
    public let eTag: String
    public let lastModifiedAt: Date
    public let storageClass: String
}

extension S3Object: Comparable {
    public static func < (lhs: S3Object, rhs: S3Object) -> Bool {
        lhs.key < rhs.key
    }
}
