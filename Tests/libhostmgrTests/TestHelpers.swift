import Foundation
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
        XCTAssertEqual(data.sha256.base64EncodedString(), hash, file: file, line: line)
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

func pathForResource(named key: String, extension: String? = nil) -> URL {
    Bundle.module.url(forResource: key, withExtension: `extension`)!
}

func dataForResource(named key: String) throws -> Data {
    let url = Bundle.module.url(forResource: key, withExtension: "dat")!
    return try Data(contentsOf: url)
}

func stringForResource(named key: String) throws -> String {
    return try String(contentsOf: pathForResource(named: key))
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
