import Foundation

public struct RemoteVMImage: FilterableByBasename {
    public let imageObject: S3Object
    public let checksumObject: S3Object

    public var imagePath: String {
        imageObject.key
    }

    public var fileName: String {
        URL(fileURLWithPath: imagePath)
            .lastPathComponent
    }

    public var basename: String {
        URL(fileURLWithPath: imagePath)
            .deletingPathExtension()
            .lastPathComponent
    }

    public var checksumKey: String {
        checksumObject.key
    }

    public var checksumFileName: String {
        basename + ".sha256.txt"
    }

    public init(imageObject: S3Object, checksumKey: String) {
        self.imageObject = imageObject
        self.checksumObject = S3Object(key: checksumKey, size: 64, modifiedAt: Date()) // Checksums are always 64 bytes
    }
}

extension RemoteVMImage: Equatable {
    public static func == (lhs: RemoteVMImage, rhs: RemoteVMImage) -> Bool {
        lhs.imageObject == rhs.imageObject && lhs.checksumKey == rhs.checksumKey
    }
}
