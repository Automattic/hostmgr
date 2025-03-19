import Foundation
import Network

import libhostmgr
@testable import hostmgr_helper

@MainActor
class MockManagedVirtualMachine: ManagedVirtualMachine {
    let config: LaunchConfiguration
    let ip: IPv4Address = .any
    let handle: String = "test-handle"

    enum State {
        case started
        case stopped
    }

    enum Errors: Error {
        case crashedAtStart
        case genericError
    }

    var state: State = .stopped

    // used to simulate an error thrown when starting
    var shouldCrashAtStart = false
    // whether the VM was asked to clean
    var cleaned = false
    // if the delegate has been set
    var delegateSet = false
    // a delay can be added to test concurrency races
    var startupDelay: Duration = .seconds(0)
    var stopDelay: Duration = .seconds(0)

    init(name: String, handle: String) {
        config = LaunchConfiguration(name: name, handle: handle)
    }

    func start() async throws {
        try await Task.sleep(for: startupDelay)
        if shouldCrashAtStart {
            throw Errors.crashedAtStart
        }
        self.state = .started
    }

    func stop() async {
        try? await Task.sleep(for: stopDelay)
        self.state = .stopped
    }

    func clean() {
        self.cleaned = true
    }

    func setDelegate(_ delegate: hostmgr_helper.VirtualMachineSlot) {
        self.delegateSet = true
    }

}
