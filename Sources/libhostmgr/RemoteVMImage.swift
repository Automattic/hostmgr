import Foundation

public struct RemoteVMImage {
    public let imageObject: S3Object
    public let checksumKey: String

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

    public init(imageObject: S3Object, checksumKey: String) {
        self.imageObject = imageObject
        self.checksumKey = checksumKey
    }
}
