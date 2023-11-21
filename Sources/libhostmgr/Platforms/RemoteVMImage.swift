import Foundation
import tinys3

public struct RemoteVMImage: Equatable {

    private let imageFile: RemoteFile

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

    public var lastModifiedAt: Date {
        imageFile.lastModifiedAt
    }

    public var path: String {
        imageFile.path
    }

    public var size: Int {
        imageFile.size
    }
}

extension RemoteVMImage {
    public static func == (lhs: RemoteVMImage, rhs: RemoteVMImage) -> Bool {
        lhs.imageFile == rhs.imageFile
    }
}
