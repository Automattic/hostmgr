import XCTest
@testable import libhostmgr

final class CacheServerFileTests: XCTestCase {
    func testThatFileListCanBeParsed() throws {
        let data = try jsonForResource(named: "caddy-file-list")
        XCTAssertEqual(try CacheServer.cache.parseFileData(data).count, 466)
    }
}
