import Foundation
@testable import libhostmgr

extension RemoteVMImage {
    static func with(
        key: String,
        size: Int = Int.random(in: 0...Int.max),
        checksumKey: String = UUID().uuidString
    ) -> RemoteVMImage {
        RemoteVMImage(
            imageObject: S3Object(key: key, size: size, modifiedAt: Date.distantPast),
            checksumKey: checksumKey
        )
    }
}

extension LocalVMImage {
    static func with(path: String) -> LocalVMImage? {
        LocalVMImage(path: URL(fileURLWithPath: path))
    }
}
