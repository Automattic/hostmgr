import XCTest
import libhostmgr
@testable import hostmgr_helper

@MainActor
class SlotMetricsWriterTests: XCTestCase {
    var primarySlot: VirtualMachineSlot!
    var secondarySlot: VirtualMachineSlot!

    override func setUp() async throws {
        primarySlot = VirtualMachineSlot(role: .primary)
        secondarySlot = VirtualMachineSlot(role: .secondary)
    }

    func testRenderReportsEachSlotsState() async throws {
        try await primarySlot.start(managedVirtualMachine: MockManagedVirtualMachine(name: "vm", handle: "job-1"))

        let lines = SlotMetricsWriter.render(slots: [primarySlot, secondarySlot]).split(separator: "\n")

        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_state{slot="primary",state="running"} 1"#))
        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_state{slot="primary",state="empty"} 0"#))
        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_state{slot="secondary",state="empty"} 1"#))
        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_available{slot="primary"} 0"#))
        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_available{slot="secondary"} 1"#))
    }

    func testRenderReportsAVMThatFailedToStop() async throws {
        let managedVirtualMachine = MockManagedVirtualMachine(name: "vm", handle: "job-1")
        try await primarySlot.start(managedVirtualMachine: managedVirtualMachine)
        managedVirtualMachine.shouldFailToStop = true
        try? await primarySlot.stop()

        let lines = SlotMetricsWriter.render(slots: [primarySlot]).split(separator: "\n")

        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_state{slot="primary",state="stop_failed"} 1"#))
        XCTAssertTrue(lines.contains(#"hostmgr_vm_slot_available{slot="primary"} 0"#))
    }

    func testRenderReportsEveryStateForEverySlot() {
        let output = SlotMetricsWriter.render(slots: [primarySlot, secondarySlot])

        let stateLines = output.split(separator: "\n").filter { $0.hasPrefix("hostmgr_vm_slot_state{") }
        XCTAssertEqual(stateLines.count, 2 * VirtualMachineSlot.State.allNames.count)
    }

    func testRenderEndsWithNewline() {
        // The text format requires the last line to end in a newline
        XCTAssertTrue(SlotMetricsWriter.render(slots: [primarySlot]).hasSuffix("\n"))
    }

    func testStateChangeUpdatesTimestamp() async throws {
        let initialTimestamp = primarySlot.stateChangedAt
        try await Task.sleep(for: .milliseconds(10))

        try await primarySlot.start(managedVirtualMachine: MockManagedVirtualMachine(name: "vm", handle: "job-1"))

        XCTAssertGreaterThan(primarySlot.stateChangedAt, initialTimestamp)
    }

    func testWriteReplacesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = SlotMetricsWriter(path: directory.appendingPathComponent("hostmgr.prom"))
        try writer.write("first\n")
        try writer.write("second\n")

        XCTAssertEqual(try String(contentsOf: writer.path, encoding: .utf8), "second\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["hostmgr.prom"])
    }
}
