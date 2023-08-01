import Foundation
import tinys3

struct AppleSiliconVMLibrary: RemoteVMLibrary {
    typealias VM = AppleSiliconRemoteVMImage

    func remoteImagesFrom(objects: [RemoteFile]) -> [AppleSiliconRemoteVMImage] {
        objects.compactMap(AppleSiliconRemoteVMImage.init)
    }
}
