import Foundation
import tinys3

public struct RemoteVMImage: FilterableByName, Equatable {
    let imageFile: RemoteFile

    init?(imageFile: RemoteFile) {
        guard imageFile.path.hasSuffix("vmtemplate.aar") else {
            return nil
        }

        self.imageFile = imageFile
    }

    public var name: String {
        URL(fileURLWithPath: imageFile.path).deletingPathExtension().deletingPathExtension().lastPathComponent
    }

    public var fileName: String {
        URL(fileURLWithPath: imageFile.path).lastPathComponent
    }

    public var basename: String {
        if architecture == .arm64 {
            return URL(fileURLWithPath: imageFile.path)
                .deletingPathExtension()
                .deletingPathExtension()
                .lastPathComponent
        } else {
            return URL(fileURLWithPath: imageFile.path)
                .deletingPathExtension()
                .lastPathComponent
        }
    }

    public var fileExtension: String {
        URL(fileURLWithPath: imageFile.path).pathExtension
    }

    public var lastModifiedAt: Date {
        imageFile.lastModifiedAt
    }

    public var checksumKey: String {
        basename + ".sha256.txt"
    }

    public var path: String {
        imageFile.path
    }

    public var size: Int {
        imageFile.size
    }

    public var architecture: ProcessorArchitecture? {
        switch fileExtension {
        case "aar": return .arm64
        case "pvmp": return .x64
        default: return nil
        }
    }
}

extension RemoteVMImage {
    public static func == (lhs: RemoteVMImage, rhs: RemoteVMImage) -> Bool {
        lhs.imageFile == rhs.imageFile
    }
}
