import XCTest
@testable import libhostmgr

final class StatsRepositoryTests: XCTestCase {

    func testThatLineIs128Bytes() {
        let row = StatsRepository.UsageLine(name: "test", category: .virtualMachine, date: Date())
        XCTAssertEqual(128, row.toData().count)
    }

    func testExample() async throws {
        let expectedDate = Date(timeIntervalSince1970: 0)
        let repo = StatsRepository(usageFile: .tempFilePath)
        try await repo.recordResourceUsage(for: "test", category: .virtualMachine, date: expectedDate)
        let latestUsage = try await repo.lookupLatestUsageForResource(withName: "test", for: .virtualMachine)

        XCTAssertEqual(latestUsage, expectedDate)
    }
}
