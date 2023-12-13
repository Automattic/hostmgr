import XCTest
@testable import tinys3

final class AWSCredentialsTests: XCTestCase {

    let credentials: AWSCredentials = .testDefault

    func testThatCredentialsFromFileThrowsForMissingFile() throws {
        let invalidURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try AWSCredentials.from(url: invalidURL))
    }
}
