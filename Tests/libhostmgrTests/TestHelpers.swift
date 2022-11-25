import Foundation
@testable import libhostmgr
@testable import tinys3

extension RemoteVMImage {
    static func with(
        key: String,
        size: Int = Int.random(in: 0...Int.max),
        checksumKey: String = UUID().uuidString
    ) -> RemoteVMImage {
        return RemoteVMImage(
            imageObject: S3Object(
                key: key,
                size: size,
                eTag: "",
                lastModifiedAt: Date.distantPast,
                storageClass: ""
            ),
            checksumObject: S3Object(
                key: checksumKey,
                size: 64, eTag: "",
                lastModifiedAt: Date.distantPast,
                storageClass: ""
            )
        )
    }
}

extension LocalVMImage {
    static func with(path: String) -> LocalVMImage? {
        LocalVMImage(path: URL(fileURLWithPath: path))
    }
}

func getPathForEnvFile(named key: String) -> URL {
    Bundle.module.url(forResource: key, withExtension: "env")!
}
