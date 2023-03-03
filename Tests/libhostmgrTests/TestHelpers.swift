import Foundation
import Virtualization

@testable import libhostmgr
@testable import tinys3

extension RemoteVMImage {
    static func with(
        key: String,
        size: Int = Int.random(in: 0...Int.max),
        checksumKey: String = UUID().uuidString
    ) -> RemoteVMImage {
        let image = S3Object(key: key, size: size, eTag: "", lastModifiedAt: Date.distantPast, storageClass: "")
        let checksum = S3Object(
            key: checksumKey,
            size: 64,
            eTag: "",
            lastModifiedAt: Date.distantPast,
            storageClass: ""
        )
        return RemoteVMImage(
            imageObject: image,
            checksumObject: checksum
        )
    }
}

extension LocalVMImage {
    static func with(path: String) -> LocalVMImage? {
        LocalVMImage(path: URL(fileURLWithPath: path))
    }
}

extension VZMacHardwareModel {
    static func createTestFixture() throws -> VZMacHardwareModel {
        try VZMacHardwareModel(dataRepresentation: dataForResource(named: "mac-hardware-model-data"))!
    }
}

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
