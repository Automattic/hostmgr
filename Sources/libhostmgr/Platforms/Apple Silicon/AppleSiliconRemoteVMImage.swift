import Foundation
import tinys3

struct AppleSiliconRemoteVMImage: RemoteVMImage, FilterableByName {

    var imageFile: RemoteFile

    init?(imageFile: RemoteFile) {
        guard imageFile.path.hasSuffix("vmpackage.aar") else {
            return nil
        }

        self.imageFile = imageFile
    }

    var name: String {
        URL(fileURLWithPath: imageFile.path).deletingPathExtension().deletingPathExtension().lastPathComponent
    }
}
