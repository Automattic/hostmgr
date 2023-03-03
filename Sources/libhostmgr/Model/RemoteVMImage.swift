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
        if architecture == .arm64 {
            return URL(fileURLWithPath: imageObject.key)
                .deletingPathExtension()
                .deletingPathExtension()
                .lastPathComponent
        } else {
            return URL(fileURLWithPath: imageObject.key)
                .deletingPathExtension()
                .lastPathComponent
        }
    }

    public var fileExtension: String {
        URL(fileURLWithPath: imageObject.key).pathExtension
    }

    public var checksumKey: String {
        checksumObject.key
    }

    public var checksumFileName: String {
        basename + ".sha256.txt"
    }

    public var architecture: ProcessorArchitecture? {
        switch fileExtension {
        case "aar": return .arm64
        case "pvmp": return .x64
        default: return nil
        }
    }
}

extension RemoteVMImage: Equatable {
    public static func == (lhs: RemoteVMImage, rhs: RemoteVMImage) -> Bool {
        lhs.imageObject == rhs.imageObject && lhs.checksumObject == rhs.checksumObject
    }
}
