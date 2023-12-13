import XCTest
@testable import tinys3

final class HelperTests: XCTestCase {

    func testThatEmptyStringHasKnownHash() throws {
        XCTAssertEqual(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            sha256Hash(data: Data("".utf8))
        )
    }

    func testThatTimestampIsValidFormat() throws {
        XCTAssertEqual("20130524T000000Z", formattedTimestamp(from: .testDefault))
    }

    func testThatDatestampIsValidFormat() throws {
        XCTAssertEqual("20130524", formattedDatestamp(from: .testDefault))
    }

    func testThatParseLastModifiedDateWorks() throws {
        XCTAssertEqual(1668644072, parseLastModifiedDate("Thu, 17 Nov 2022 00:14:32 GMT")?.timeIntervalSince1970)
    }

    func testThatParseISO8601StringWorks() throws {
        XCTAssertEqual(1667779723, parseISO8601String("2022-11-07T00:08:43.000Z")?.timeIntervalSince1970)
    }

    // MARK: Progress
    func testThatCalculatedThroughputIsCorrect() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 50
        progress.estimateThroughput(fromTimeElapsed: 5)
        XCTAssertEqual(10, progress.throughput)
    }

    func testThatCalculatedThroughputIsZeroForZeroProgress() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 0
        progress.estimateThroughput(fromTimeElapsed: 5)
        XCTAssertEqual(0, progress.throughput)
    }

    func testThatEstimatedThroughputIsZeroForZeroTimeElapsed() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 25
        progress.estimateThroughput(fromTimeElapsed: 0)
        XCTAssertEqual(0, progress.throughput)
    }

    func testThatEstimatedTimeRemainingIsCorrect() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 50
        progress.estimateThroughput(fromTimeElapsed: 5)
        XCTAssertEqual(5, progress.estimatedTimeRemaining)
    }

    func testThatEstimatedTimeRemainingIsInfinityForZeroProgress() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 0
        progress.estimateThroughput(fromTimeElapsed: 5)
        XCTAssertEqual(.infinity, progress.estimatedTimeRemaining)
    }

    func testThatEstimatedTimeRemainingIsInfinityForZeroTimeElapsed() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 10
        progress.estimateThroughput(fromTimeElapsed: 0)
        XCTAssertEqual(.infinity, progress.estimatedTimeRemaining)
    }

    // MARK: Data
    func testThatDataHexEncodedStringReturnsValidResults() throws {
        XCTAssertEqual("f09f988c", Data("😌".utf8).hexEncodedString())
        XCTAssertEqual("F09F988C", Data("😌".utf8).hexEncodedString(options: .upperCase))
    }

    // MARK: Hashing
    func testThatHashingEmptyStringProducesValidResults() throws {
        XCTAssertEqual("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", sha256Hash(string: ""))
    }

    // MARK: URLQueryItem
    func testThatURLQueryItemEscapedValueEncodesSlashes() throws {
        XCTAssertEqual("my%2Fpath%2F", URLQueryItem(name: "prefix", value: testPrefix).escapedValue)
    }

    func testThatURLQueryItemCollectionAsEscapedQueryStringProperlyHandlesNilValues() throws {
        XCTAssertEqual("hasnovalue=&name=value", [
            URLQueryItem(name: "hasnovalue", value: nil),
            URLQueryItem(name: "name", value: "value")
        ].asEscapedQueryString)
    }

    func testThatURLQueryItemEscapedValueReturnsNilForNilValue() {
        XCTAssertNil(URLQueryItem(name: "name", value: nil).escapedValue)
    }
}
