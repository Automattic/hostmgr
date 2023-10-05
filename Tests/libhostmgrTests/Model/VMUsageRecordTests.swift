import XCTest
@testable import libhostmgr

final class VMUsageRecordTests: XCTestCase {

    let records = [
        VMUsageRecord(vm: "test", date: Date(timeIntervalSince1970: 1)),
        VMUsageRecord(vm: "test", date: Date(timeIntervalSince1970: 2)),
    ].shuffled()

    func testThatMergingRecordsRetainsLatestValue() throws {
        XCTAssertEqual(
            2,
            VMUsageAggregate.from(records)?.lastUsed.timeIntervalSince1970
        )
    }

    func testThatMergingRecordsIncrementsCount() throws {
        XCTAssertEqual(
            2,
            VMUsageAggregate.from(record: records.first!).merging(records.last!).count
        )
    }

    func testThatAggregatingNoRecordsReturnsNil() throws {
        XCTAssertNil(VMUsageAggregate.from([]))
    }

    func testThatGroupingRecordsProducesCorrectLastUsedValue() throws {
        XCTAssertEqual(2, records.grouped().first?.lastUsed.timeIntervalSince1970)
    }

    func testThatGroupingRecordsProducesCorrectCount() throws {
        XCTAssertEqual(2, records.grouped().first?.count)
    }

    func testThatQueryingGroupedRecordsForUnusedReturnsCorrectResult() throws {
        XCTAssert(records.grouped().unused(since: Date(timeIntervalSince1970: 2)).isEmpty)
        XCTAssertEqual(1, records.grouped().unused(since: Date(timeIntervalSince1970: 3)).count)
    }
}
