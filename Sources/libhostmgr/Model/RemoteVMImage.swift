import Foundation
import tinys3

public struct RemoteVMImage: FilterableByBasename {
    public let imageObject: S3Object
    public let checksumObject: S3Object

    public var fileName: String {
        URL(fileURLWithPath: imageObject.key)
            .lastPathComponent
    }

    public var basename: String {
        URL(fileURLWithPath: imageObject.key)
            .deletingPathExtension()
            .lastPathComponent
    }

    public var checksumFileName: String {
        basename + ".sha256.txt"
    }
}

extension RemoteVMImage: Equatable {
    public static func == (lhs: RemoteVMImage, rhs: RemoteVMImage) -> Bool {
        lhs.imageObject == rhs.imageObject && lhs.checksumObject == rhs.checksumObject
    }
}
