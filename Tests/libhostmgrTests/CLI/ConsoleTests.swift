import XCTest
@testable import libhostmgr

final class ConsoleTests: XCTestCase {

    // MARK: Table Calculations
    func testThatColumnCountWorks() throws {
        let table = [["Jack", "Reacher"], ["James", "Bond"], ["Jason", "Bourne"]]
        XCTAssertEqual([5, 7], Console().columnCounts(for: table))
    }

    func testThatTransposeWorks() throws {
        let original = [
            ["Jack", "Reacher"],
            ["James", "Bond"],
            ["Jason", "Bourne"]
        ]
        let transposed = [
            ["Jack", "James", "Jason"],
            ["Reacher", "Bond", "Bourne"]
        ]
        XCTAssertEqual(transposed, Console().transpose(matrix: original))
    }
}
