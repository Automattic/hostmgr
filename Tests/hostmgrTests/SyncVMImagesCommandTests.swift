import XCTest

class SyncVMImagesCommandTests: XCTestCase {

}

// MARK: Internal State Tests
class SyncVMImagesCommandStateTests: XCTestCase {
    func testThatIsRunningIsTrueWhenRunRecently() {
        var state = SyncVMImagesCommand.State()
        state.heartbeat = Date()
        XCTAssertTrue(state.isRunning)
    }
}
