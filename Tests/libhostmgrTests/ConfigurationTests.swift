import Foundation
import XCTest
@testable import libhostmgr

final class ConfigurationTests: XCTestCase {

    func testThatEmptyConfigurationUsesDefaults() {
        XCTAssertEqual(
            Configuration().syncTasks,
            Configuration.Defaults.defaultSyncTasks
        )

        XCTAssertEqual(
            Configuration().gitMirrorPort,
            Configuration.Defaults.defaultGitMirrorPort
        )
        XCTAssertEqual(
            Configuration().allowAWSAcceleratedTransfer,
            Configuration.Defaults.defaultAWSAcceleratedTransferAllowed
        )
        XCTAssertEqual(
            Configuration().awsConfigurationMethod,
            Configuration.Defaults.defaultAWSConfigurationMethod
        )
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
        XCTAssertEqual(123456, configuration.authorizedKeysSyncInterval)
        XCTAssertEqual("us-east-2", configuration.authorizedKeysRegion)

        XCTAssertEqual("vm-images-bucket", configuration.vmImagesBucket)
        XCTAssertEqual("us-east-2", configuration.vmImagesRegion)

        XCTAssertEqual("git-mirror-bucket", configuration.gitMirrorBucket)
        XCTAssertEqual(123456, configuration.gitMirrorPort)

        XCTAssertEqual(["foo-bar-baz"], configuration.protectedImages)
        XCTAssertEqual([.vmImages], configuration.syncTasks)
    }

    func testThatConfigurationWithoutLocalGitMirrorPortUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(Configuration.Defaults.defaultGitMirrorPort, configuration.gitMirrorPort)
    }

    func testThatConfigurationWithoutAWSAccelerationSettingUsesDefault() throws {
        let data = getJSONDataForResource(named: "defaults")
        let configuration = try Configuration.from(data: data)
        XCTAssertEqual(
            Configuration.Defaults.defaultAWSAcceleratedTransferAllowed,
            configuration.allowAWSAcceleratedTransfer
        )
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
