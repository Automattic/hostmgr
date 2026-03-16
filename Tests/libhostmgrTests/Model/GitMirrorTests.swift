import XCTest
@testable import libhostmgr

final class GitMirrorTests: XCTestCase {

    private let subject = GitMirror.from(string: "git@github.com:Automattic/hostmgr.git")!

    func testThatRemoteFilenameIsCorrect() throws {
        XCTAssertEqual(
            "git-github-com-Automattic-hostmgr-git-2023-08.aar",
            subject.calculateRemoteFilename(given: Date(timeIntervalSince1970: 1691801518))
        )
    }

    func testThatRemoteFilenameUsesCalendarYearNearYearBoundary() throws {
        // Dec 31, 2024 — ISO week-year (YYYY) would produce "2025", calendar year (yyyy) should produce "2024"
        let dec31 = Date(timeIntervalSince1970: 1735603200)
        XCTAssertEqual(
            "git-github-com-Automattic-hostmgr-git-2024-12.aar",
            subject.calculateRemoteFilename(given: dec31)
        )
    }

    func testThatRemoteFilenameUsesUTCTimezone() throws {
        // Jan 1, 2025 00:30 UTC — without explicit UTC, machines in western timezones
        // (e.g. US/Pacific = UTC-8) would see this as Dec 31, 2024 and produce "2024-12"
        let jan1UTC = Date(timeIntervalSince1970: 1735691400)
        XCTAssertEqual(
            "git-github-com-Automattic-hostmgr-git-2025-01.aar",
            subject.calculateRemoteFilename(given: jan1UTC)
        )
    }

    func testThatErrorIsThrownForMissingEnvironmentVariable() throws {
        XCTAssertThrowsError(try GitMirror.fromEnvironment(key: "foo"))
    }

    func testThatEnvironmentVariableIsDetectedCorrectly() throws {
        let environment = ["TEST_KEY": "git@github.com:Automattic/hostmgr.git"]
        XCTAssertNotNil(try GitMirror.fromEnvironment(key: "TEST_KEY", environment: environment))
    }

    func testThatErrorIsThrownIfEnvironmentVariableIsNotURL() throws {
        let environment = ["TEST_KEY": ""]
        XCTAssertThrowsError(try GitMirror.fromEnvironment(key: "TEST_KEY", environment: environment))
    }
}
