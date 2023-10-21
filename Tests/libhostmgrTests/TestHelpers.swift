import Foundation
import CryptoKit
import Virtualization
import XCTest

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

extension XCTest {
    func XCTAssert(_ data: Data, hasHash hash: String, file: StaticString = #file, line: UInt = #line) {
        var hasher = SHA256()
        hasher.update(data: data)
        XCTAssertEqual(Data(hasher.finalize()).base64EncodedString(), hash, file: file, line: line)
    }
}

func getPathForEnvFile(named key: String) -> URL {
    Bundle.module.url(forResource: key, withExtension: "env")!
}

func pathForResource(named key: String, extension: String? = nil) -> URL {
    Bundle.module.url(forResource: key, withExtension: `extension`)!
}

func jsonForResource(named key: String) throws -> Data {
    let url = Bundle.module.url(forResource: key, withExtension: "json")!
    return try Data(contentsOf: url).dropLast()
}

class MockFileManager: FileManagerProto {

    let existingFiles: [String]
    let existingDirectories: [String]

    init(existingFiles: [URL] = [], existingDirectories: [URL] = []) {
        self.existingFiles = existingFiles.map { $0.path() }
        self.existingDirectories = existingDirectories.map { $0.path() }
    }

    func fileExists(at url: URL) -> Bool {
        existingFiles.firstIndex(of: url.path()) != nil
    }

    func directoryExists(at url: URL) throws -> Bool {
        existingDirectories.firstIndex(of: url.path()) != nil
    }
}

extension FileHasher {
    static func stringRepresentationForHash(ofFileAt url: URL) throws -> String {
        try hash(fileAt: url).compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension ProcessInfo {
    var processorArchitecture: ProcessorArchitecture {
        var sysinfo = utsname()
        uname(&sysinfo)
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        let identifier = String(bytes: data, encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        return ProcessorArchitecture(rawValue: identifier)!
    }
}

extension S3Object {
    var asFile: RemoteFile {
        RemoteFile(size: size, path: key, lastModifiedAt: lastModifiedAt)
    }
}

extension Date {
    static let testDefault = Date(timeIntervalSinceReferenceDate: 0)
}
