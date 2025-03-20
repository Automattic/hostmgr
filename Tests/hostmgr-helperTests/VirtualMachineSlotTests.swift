import XCTest
import libhostmgr
@testable import hostmgr_helper

@MainActor
class VirtualMachineSlotTests: XCTestCase {
    var managedVirtualMachine: MockManagedVirtualMachine!
    var slot: VirtualMachineSlot!

    override func setUp() async throws {
        managedVirtualMachine = MockManagedVirtualMachine(name: "test-name", handle: "test-handle")
        slot = VirtualMachineSlot(role: .primary)
    }

    func testStartingAndStoppingVM() async throws {
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        XCTAssertEqual(managedVirtualMachine.state, .started)
        XCTAssertEqual(slot.state, .running(managedVirtualMachine))
        try await slot.stop()
        XCTAssertEqual(slot.state, .empty)
        XCTAssertEqual(managedVirtualMachine.state, .stopped)
        XCTAssertEqual(managedVirtualMachine.cleaned, false)
    }

    func testCancelledStart() async throws {
        // Make the startup a little slower so we can sneak a stop() call in
        managedVirtualMachine.startupDelay = .seconds(5)

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                do {
                    try await self.slot.start(managedVirtualMachine: self.managedVirtualMachine)
                } catch VirtualMachineSlot.Errors.vmStartCancelled {
                    // Expected
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }

            group.addTask { @MainActor in
                // Give the slot a moment to switch to .starting
                try await Task.sleep(for: .seconds(2))
                switch self.slot.state {
                case .starting: break
                default: XCTFail("Expected to be in the starting state.")
                }
                // This should stop a starting a VM, throwing the expected error.
                try await self.slot.stop()
            }
        }

        XCTAssertEqual(slot.state, .empty)
        XCTAssertEqual(managedVirtualMachine.state, .stopped)
    }

    func testCallingStartWhileUnavailable() async throws {
        let newManagedVirtualMachine = MockManagedVirtualMachine(name: "new-name", handle: "new-handle")
        try await self.slot.start(managedVirtualMachine: self.managedVirtualMachine)

        XCTAssertEqual(self.slot.isAvailable, false)
        do {
            try await self.slot.start(managedVirtualMachine: newManagedVirtualMachine)
        } catch VirtualMachineSlot.Errors.invalidStartState {
            // Expected
        } catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertEqual(managedVirtualMachine.state, .started)
        XCTAssertTrue(slot.isConfiguredForHandle(managedVirtualMachine.handle))
        XCTAssertEqual(newManagedVirtualMachine.state, .stopped)
    }

    func testSlotReturnsToEmptyState() async throws {
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        try await slot.stop()
        XCTAssertEqual(slot.state, .empty)
    }

    func testSlotReturnsToCrashedState() async throws {
        managedVirtualMachine.shouldCrashAtStart = true
        try? await slot.start(managedVirtualMachine: managedVirtualMachine)
        XCTAssertEqual(slot.state, .crashed(MockManagedVirtualMachine.Errors.crashedAtStart))
    }

    func testCallingStopWithoutClean() async throws {
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        try await slot.stop(clean: false)
        XCTAssertEqual(managedVirtualMachine.state, .stopped)
        XCTAssertEqual(managedVirtualMachine.cleaned, false)
    }

    func testCallingStopAndClean() async throws {
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        try await slot.stop(clean: true)
        XCTAssertEqual(managedVirtualMachine.state, .stopped)
        XCTAssertEqual(managedVirtualMachine.cleaned, true)
    }

    func testCallingStopAndCleanWithError() async throws {
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        try await slot.stop(withError: MockManagedVirtualMachine.Errors.genericError, clean: true)
        XCTAssertEqual(slot.state, .crashed(MockManagedVirtualMachine.Errors.genericError))
        XCTAssertEqual(managedVirtualMachine.state, .stopped)
        XCTAssertEqual(managedVirtualMachine.cleaned, true)
    }

    func testAvailability() async throws {
        XCTAssertEqual(slot.isAvailable, true)
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        XCTAssertEqual(slot.isAvailable, false)
        try await slot.stop()
        XCTAssertEqual(slot.isAvailable, true)
    }

    func testIsConfiguredForHandle() async throws {
        XCTAssertFalse(slot.isConfiguredForHandle("test-handle"))
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        XCTAssertTrue(slot.isConfiguredForHandle("test-handle"))
        XCTAssertFalse(slot.isConfiguredForHandle("test-handle-bad"))
        try await slot.stop()
        XCTAssertFalse(slot.isConfiguredForHandle("test-handle"))
    }

    func testDelegateSettings() async throws {
        XCTAssertFalse(managedVirtualMachine.delegateSet)
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        XCTAssertTrue(managedVirtualMachine.delegateSet)
    }

    func testErrorThrownWhenStopCalledWhileStopping() async throws {
        managedVirtualMachine.stopDelay = .seconds(5)
        try await slot.start(managedVirtualMachine: managedVirtualMachine)
        XCTAssertEqual(managedVirtualMachine.state, .started)

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await self.slot.stop()
            }

            group.addTask { @MainActor in
                // Give the slot a moment to switch to .stopping
                try await Task.sleep(for: .seconds(1))
                switch self.slot.state {
                case .stopping: break
                default: XCTFail("Expected to be in the starting state.")
                }

                do {
                    try await self.slot.stop()
                } catch VirtualMachineSlot.Errors.invalidStopState {
                    // Expected
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }
        }
    }
}
