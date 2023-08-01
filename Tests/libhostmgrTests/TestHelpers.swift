import Foundation
import Virtualization

@testable import libhostmgr
@testable import tinys3

extension ParallelsVMImage {
    static func with(
        key: String,
        size: Int = Int.random(in: 0...Int.max),
        checksumKey: String = UUID().uuidString
    ) -> ParallelsVMImage? {
        let image = S3Object(key: key, size: size, eTag: "", lastModifiedAt: Date.distantPast, storageClass: "")
        let checksum = S3Object(
            key: checksumKey,
            size: 64,
            eTag: "",
            lastModifiedAt: Date.distantPast,
            storageClass: ""
        )

        return ParallelsVMImage.with(
            imageObject: image,
            checksumObject: checksum
        )
    }

    static func with(imageObject: S3Object, checksumObject: S3Object) -> ParallelsVMImage? {
        ParallelsVMImage(path: URL(fileURLWithPath: imageObject.key))
    }
}

// extension LocalVMImage {
//    static func with(path: String) -> any LocalVMImage? {
//        LocalVMImage(path: URL(fileURLWithPath: path))
//    }
// }

extension S3Object {
    static func with(
        key: String,
        size: Int,
        eTag: String = "",
        lastModifiedAt: Date = Date(),
        storageClass: String = ""
    ) -> S3Object {
        S3Object(key: key, size: size, eTag: eTag, lastModifiedAt: lastModifiedAt, storageClass: storageClass)
    }
}

#if arch(arm64)
extension VZMacHardwareModel {
    static func createTestFixture() throws -> VZMacHardwareModel {
        try VZMacHardwareModel(dataRepresentation: dataForResource(named: "mac-hardware-model-data"))!
    }
}
#endif

func getPathForEnvFile(named key: String) -> URL {
    Bundle.module.url(forResource: key, withExtension: "env")!
}

func pathForResource(named key: String) -> URL {
    Bundle.module.url(forResource: key, withExtension: nil)!
}

func dataForResource(named key: String) throws -> Data {
    let url = Bundle.module.url(forResource: key, withExtension: "dat")!
    return try Data(contentsOf: url)
}

func jsonForResource(named key: String) throws -> Data {
    let url = Bundle.module.url(forResource: key, withExtension: "json")!
    return try Data(contentsOf: url)
}
