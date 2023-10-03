import Foundation
import Virtualization

@testable import libhostmgr
@testable import tinys3

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
