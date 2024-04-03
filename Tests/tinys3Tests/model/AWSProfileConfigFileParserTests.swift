import XCTest
@testable import tinys3

final class AWSProfileConfigFileParserTests: XCTestCase {

    // MARK: Test Parsing Credential Files

    func testThatSingleCredsFileContainsDefaultProfile() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSCredentialsFile.single, fileType: .credentials)
        let defaultProfile = try XCTUnwrap(profiles["default"])
        XCTAssertEqual(defaultProfile.values.count, 4)
        XCTAssertEqual(defaultProfile["aws_access_key_id"], "AKIAIOSFODNN7EXAMPLE")
        XCTAssertEqual(defaultProfile["aws_secret_access_key"], "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
        XCTAssertEqual(defaultProfile["region"], "us-east-1")
        XCTAssertEqual(defaultProfile["output"], "text")
    }

    func testThatMultipleCredsFileContainsOtherCredentials() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSCredentialsFile.multiple, fileType: .credentials)
        let minioProfile = try XCTUnwrap(profiles["minio"])
        XCTAssertEqual(minioProfile.values.count, 4)
        XCTAssertEqual(minioProfile["aws_access_key_id"], "minioadmin")
        XCTAssertEqual(minioProfile["aws_secret_access_key"], "minioadmin")
        XCTAssertEqual(minioProfile["region"], "us-east-1")
        XCTAssertEqual(minioProfile["some_invalid_key"], "foo")
    }

    func testThatNonExistantCredsProfileIsNil() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSCredentialsFile.single, fileType: .credentials)
        XCTAssertNil(profiles["invalid"])
    }

    func testThatNonProfileSectionsAreNotParsedAsProfile() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSCredentialsFile.multiple, fileType: .credentials)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profiles.keys.sorted(), ["default", "invalid", "minio"])
    }

    func testThatCredsProfileWithInvalidKeysIsEmpty() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSCredentialsFile.multiple, fileType: .credentials)
        let profile = try XCTUnwrap(profiles["invalid"])
        XCTAssertTrue(profile.values.isEmpty)
    }

    // MARK: Test Parsing Config Files

    func testThatSingleConfigFileContainsDefaultProfile() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSUserConfigFile.single, fileType: .config)
        let defaultProfile = try XCTUnwrap(profiles["default"])
        XCTAssertEqual(defaultProfile.values.count, 2)
        XCTAssertEqual(defaultProfile["region"], "us-east-2")
        XCTAssertEqual(defaultProfile["output"], "yaml")
    }

    func testThatMultipleConfigFileContainsOtherCredentials() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSUserConfigFile.multiple, fileType: .config)
        let minioProfile = try XCTUnwrap(profiles["minio"])
        XCTAssertEqual(minioProfile.values.count, 2)
        XCTAssertEqual(minioProfile["region"], "us-east-1")
        XCTAssertEqual(minioProfile["some_invalid_key"], "foo")
    }

    func testThatNonExistantConfigProfileIsNil() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSUserConfigFile.single, fileType: .config)
        XCTAssertNil(profiles["invalid"])
    }

    func testThatConfigProfileWithInvalidKeysIsEmpty() throws {
        let profiles = try AWSProfileConfigFileParser.profiles(from: try R.AWSUserConfigFile.multiple, fileType: .config)
        let profile = try XCTUnwrap(profiles["invalid"])
        XCTAssertTrue(profile.values.isEmpty)
    }

    func testThatMissingUserConfigFileThrows() throws {
        let nonExistingFile = URL(filePath: "/non-existing-file")
        XCTAssertThrowsError(
            try AWSProfileConfigFileParser.profiles(from: nonExistingFile, fileType: .credentials)
        )
    }
}
