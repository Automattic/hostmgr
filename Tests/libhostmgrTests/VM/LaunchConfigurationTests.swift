import XCTest
import libhostmgr

final class LaunchConfigurationTests: XCTestCase {

    func testThatLaunchConfigurationHandleReturnsGivenValueForNonPersistentConfigurations() throws {
        XCTAssertEqual("bar", LaunchConfiguration(name: "foo", handle: "bar", persistent: false).handle)
    }

    func testThatLaunchConfigurationHandleReturnsNameForPersistentConfigurations() throws {
        XCTAssertEqual("foo", LaunchConfiguration(name: "foo", handle: "bar", persistent: true).handle)
    }
}
