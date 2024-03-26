import XCTest
@testable import tinys3

final class AWSProfileConfigTests: XCTestCase {

    // MARK: Test Parsing Credential Files

    func testThatSingleCredsFileContainsDefaultProfile() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSCredentialsFile.single, isCredentialsFile: true)
        let defaultProfile = try XCTUnwrap(profiles["default"])
        XCTAssertEqual(defaultProfile.values.count, 4)
        XCTAssertEqual(defaultProfile["aws_access_key_id"], "AKIAIOSFODNN7EXAMPLE")
        XCTAssertEqual(defaultProfile["aws_secret_access_key"], "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
        XCTAssertEqual(defaultProfile["region"], "us-east-1")
        XCTAssertEqual(defaultProfile["output"], "text")
    }

    func testThatMultipleCredsFileContainsOtherCredentials() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSCredentialsFile.multiple, isCredentialsFile: true)
        let minioProfile = try XCTUnwrap(profiles["minio"])
        XCTAssertEqual(minioProfile.values.count, 4)
        XCTAssertEqual(minioProfile["aws_access_key_id"], "minioadmin")
        XCTAssertEqual(minioProfile["aws_secret_access_key"], "minioadmin")
        XCTAssertEqual(minioProfile["region"], "us-east-1")
        XCTAssertEqual(minioProfile["some_invalid_key"], "foo")
    }

    func testThatNonExistantCredsProfileIsNil() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSCredentialsFile.single, isCredentialsFile: true)
        XCTAssertNil(profiles["invalid"])
    }

    func testThatNonProfileSectionsAreNotParsedAsProfile() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSCredentialsFile.multiple, isCredentialsFile: true)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profiles.keys.sorted(), ["default", "invalid", "minio"])
    }

    func testThatCredsProfileWithInvalidKeysIsEmpty() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSCredentialsFile.multiple, isCredentialsFile: true)
        let profile = try XCTUnwrap(profiles["invalid"])
        XCTAssertTrue(profile.values.isEmpty)
    }

    // MARK: Test Parsing Config Files

    func testThatSingleConfigFileContainsDefaultProfile() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSUserConfigFile.single, isCredentialsFile: false)
        let defaultProfile = try XCTUnwrap(profiles["default"])
        XCTAssertEqual(defaultProfile.values.count, 2)
        XCTAssertEqual(defaultProfile["region"], "us-east-2")
        XCTAssertEqual(defaultProfile["output"], "yaml")
    }

    func testThatMultipleConfigFileContainsOtherCredentials() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSUserConfigFile.multiple, isCredentialsFile: false)
        let minioProfile = try XCTUnwrap(profiles["minio"])
        XCTAssertEqual(minioProfile.values.count, 2)
        XCTAssertEqual(minioProfile["region"], "us-east-1")
        XCTAssertEqual(minioProfile["some_invalid_key"], "foo")
    }

    func testThatNonExistantConfigProfileIsNil() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSUserConfigFile.single, isCredentialsFile: false)
        XCTAssertNil(profiles["invalid"])
    }

    func testThatConfigProfileWithInvalidKeysIsEmpty() throws {
        let profiles = try AWSProfileConfig.profiles(from: try R.AWSUserConfigFile.multiple, isCredentialsFile: false)
        let profile = try XCTUnwrap(profiles["invalid"])
        XCTAssertTrue(profile.values.isEmpty)
    }

    func testThatMissingUserConfigFileThrows() throws {
        let nonExistingFile = URL(filePath: "/non-existing-file")
        XCTAssertThrowsError(
            try AWSProfileConfig.profiles(from: nonExistingFile, isCredentialsFile: true)
        )
    }
}
