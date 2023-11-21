import XCTest
@testable import libhostmgr

final class VMUsageTrackerTests: XCTestCase {

    private let sampleFile = pathForResource(named: "usage-file-sample")

    func testThatUsageRecordsAreReadCorrectly() async throws {
        let stats = try await VMUsageTracker(usageFilePath: sampleFile).usageStats()
        XCTAssertEqual(5, stats.count)
    }

    func testThatUsageRecordsAreWrittenCorrectly() async throws {
        let path = try FileManager.default.createTemporaryFile()
        try await VMUsageTracker(usageFilePath: path).trackUsageOf(vmNamed: "foo", on: .testDefault)
        try XCTAssertEqual(String(contentsOf: path), "foo\t2001-01-01T00:00:00Z\n")
    }

    func testThatUsageFileParentDirectoryIsAutomaticallyCreated() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try await VMUsageTracker(usageFilePath: path.appendingPathComponent("foo")).trackUsageOf(vmNamed: "bar")
        try XCTAssertTrue(FileManager.default.directoryExists(at: path))
    }

    func testThatUsageFileIsAutomaticallyCreated() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("foo")
        try await VMUsageTracker(usageFilePath: path).trackUsageOf(vmNamed: "bar")
        XCTAssertTrue(FileManager.default.fileExists(at: path))
    }
}
