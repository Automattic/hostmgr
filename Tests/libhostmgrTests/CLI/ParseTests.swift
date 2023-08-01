import XCTest
@testable import libhostmgr

final class ParseTests: XCTestCase {

    func testThatParseCaddyDatetimeParsesFullDatetimeStrings() throws {
        XCTAssertEqual(Parse.caddyDatetime("2023-02-22T03:48:32Z")?.timeIntervalSince1970, 1677037712)
    }

}
