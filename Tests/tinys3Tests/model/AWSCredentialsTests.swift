import XCTest
@testable import tinys3

final class AWSCredentialsTests: XCTestCase {

    func testThatSingleFileContainsValidCredentials() throws {
        let profiles = try R.AWSCredentialsFixture.single.profiles
        let defaultConfig = try XCTUnwrap(profiles[.default])
        XCTAssertEqual(
            try AWSCredentials.from(configs: [defaultConfig]),
            AWSCredentials.testDefault
        )
    }

    func testThatMultipleFileContainsValidDefaultCredentials() throws {
        let profiles = try R.AWSCredentialsFixture.multiple.profiles
        let defaultConfig = try XCTUnwrap(profiles[.default])
        XCTAssertEqual(
            try AWSCredentials.from(configs: [defaultConfig]),
            AWSCredentials.testDefault
        )
    }

    func testThatMultipleFileContainsValidMinioCredentials() throws {
        let profiles = try R.AWSCredentialsFixture.multiple.profiles
        let config = try XCTUnwrap(profiles["minio"])
        XCTAssertEqual(
            try AWSCredentials.from(configs: [config]),
            AWSCredentials(accessKeyId: "minioadmin", secretKey: "minioadmin", region: "us-east-1")
        )
    }

    func testThatFileWithoutRegionThrows() throws {
        let profiles = try R.AWSCredentialsFixture.withoutRegion.profiles
        let defaultConfig = try XCTUnwrap(profiles[.default])
        XCTAssertThrowsError(
            try AWSCredentials.from(configs: [defaultConfig])
        )
    }

    func testThatCombinedProfilesContainsValidCredentials() throws {
        let credsProfiles = try R.AWSCredentialsFixture.withoutRegion.profiles
        let defaultFromCreds = try XCTUnwrap(credsProfiles[.default])

        let confProfiles = try R.AWSUserConfigFixture.single.profiles
        let defaultFromConfig = try XCTUnwrap(confProfiles[.default])

        let creds = try AWSCredentials.from(configs: [defaultFromConfig, defaultFromCreds])

        XCTAssertEqual(creds.accessKeyId, AWSCredentials.testDefault.accessKeyId)
        XCTAssertEqual(creds.secretKey, AWSCredentials.testDefault.secretKey)
        XCTAssertEqual(creds.region, "us-east-2")
    }

    func testThatValuesFromFirstConfigsTakePrecedence() throws {
        let credsProfiles = try R.AWSCredentialsFixture.single.profiles
        let defaultFromCreds = try XCTUnwrap(credsProfiles[.default])

        let confProfiles = try R.AWSUserConfigFixture.single.profiles
        let defaultFromConfig = try XCTUnwrap(confProfiles[.default])

        let creds = try AWSCredentials.from(configs: [defaultFromConfig, defaultFromCreds])

        XCTAssertEqual(creds.accessKeyId, AWSCredentials.testDefault.accessKeyId)
        XCTAssertEqual(creds.secretKey, AWSCredentials.testDefault.secretKey)
        // Ensure that, when a region is specified in *both* files, the first one takes precedence
        XCTAssertEqual(creds.region, defaultFromConfig["region"])
        XCTAssertNotEqual(creds.region, defaultFromCreds["region"])
    }
}
