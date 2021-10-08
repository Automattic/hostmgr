import Foundation
import XCTest
@testable import libhostmgr

final class ConfigurationTests: XCTestCase {

    func testThatEmptyConfigurationUsesDefaults() {
        XCTAssertEqual(Configuration().syncTasks, Configuration.Defaults.defaultSyncTasks)

        XCTAssertEqual(Configuration().localImageStorageDirectory, Configuration.Defaults.defaultLocalImageStorageDirectory)
        XCTAssertEqual(Configuration().localGitMirrorStorageDirectory, Configuration.Defaults.defaultLocalGitMirrorStorageDirectory)
        XCTAssertEqual(Configuration().gitMirrorPort, Configuration.Defaults.defaultGitMirrorPort)

        XCTAssertEqual(Configuration().allowAWSAcceleratedTransfer, Configuration.Defaults.defaultAWSAcceleratedTransferAllowed)
        XCTAssertEqual(Configuration().awsConfigurationMethod, Configuration.Defaults.defaultAWSConfigurationMethod)

        XCTAssertEqual(Configuration().localAuthorizedKeys, Configuration.Defaults.defaultLocalAuthorizedKeysFilePath)
    }

    func testThatv060ConfigurationCanBeParsed() throws {
        let data = getJSONDataForResource(named: "0.6.0")
        let configuration = try Configuration.from(data: data)
        XCTAssertNotNil(configuration)
    }

    func testThatCustomValuesOverrideDefaults() throws {
        let data = getJSONDataForResource(named: "0.6.0")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual("authorized-keys-bucket", configuration.authorizedKeysBucket)
        XCTAssertEqual("authorized-keys-path", configuration.localAuthorizedKeys)
        XCTAssertEqual(123456, configuration.authorizedKeysSyncInterval)
        XCTAssertEqual(.useast2, configuration.authorizedKeysRegion)

        XCTAssertEqual("vm-images-bucket", configuration.vmImagesBucket)
        XCTAssertEqual(.useast2, configuration.vmImagesRegion)
        XCTAssertEqual("image-storage-dir", configuration.localImageStorageDirectory)

        XCTAssertEqual("git-mirror-storage-dir", configuration.localGitMirrorStorageDirectory)
        XCTAssertEqual("git-mirror-bucket", configuration.gitMirrorBucket)
        XCTAssertEqual(123456, configuration.gitMirrorPort)

        XCTAssertEqual(["foo-bar-baz"], configuration.protectedImages)
        XCTAssertEqual([.vmImages], configuration.syncTasks)
    }

    func testThatConfigurationWithoutLocalImageStorageDirectoryUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(Configuration.Defaults.defaultLocalImageStorageDirectory, configuration.vmStorageDirectory.path)
    }

    func testThatConfigurationWithoutLocalGitMirrorStorageDirectoryUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(Configuration.Defaults.defaultLocalGitMirrorStorageDirectory, configuration.gitMirrorDirectory.path)
    }

    func testThatConfigurationWithoutLocalGitMirrorPortUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(Configuration.Defaults.defaultGitMirrorPort, configuration.gitMirrorPort)
    }

    func testThatConfigurationWithoutAWSAccelerationSettingUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(Configuration.Defaults.defaultAWSAcceleratedTransferAllowed, configuration.allowAWSAcceleratedTransfer)
    }

    func testThatConfigurationWithoutSyncTasksUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(Configuration.Defaults.defaultSyncTasks, configuration.syncTasks)
    }

    func testThatConfigurationWithoutProtectedImagesReturnsEmptyList() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertTrue(configuration.protectedImages.isEmpty)
    }

    private func getJSONDataForResource(named key: String) -> Data {
        let path = Bundle.module.path(forResource: key, ofType: "json")!
        return FileManager.default.contents(atPath: path)!
    }
}
