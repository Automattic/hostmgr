import Foundation
import tinys3

public struct ParallelsRemoteVMImage: RemoteVMImage {
    public var imageFile: RemoteFile

    public init?(imageFile: RemoteFile) {
        guard "pvmp" == URL(fileURLWithPath: imageFile.path).pathExtension else {
            return nil
        }

        self.imageFile = imageFile
    }

    public var checksumFileName: String {
        name + ".sha256.txt"
    }

    public var checksumPath: String {
        URL(fileURLWithPath: "/" + imageFile.path)
            .deletingPathExtension()
            .appendingPathExtension("sha256.txt")
            .path
    }
}
