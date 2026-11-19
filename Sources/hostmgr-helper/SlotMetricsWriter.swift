import Foundation
import OSLog
import libhostmgr

/// Writes the state of the VM slots in the Prometheus text format, for node_exporter's textfile collector.
///
/// The file is rewritten on an interval rather than on each state change, so its modification time
/// (node_exporter's `node_textfile_mtime_seconds`) also shows whether the helper is still running.
@MainActor
struct SlotMetricsWriter {
    let path: URL
    var interval: Duration = .seconds(15)

    func run(slots: () -> [VirtualMachineSlot]) async {
        while !Task.isCancelled {
            do {
                try write(Self.render(slots: slots()))
            } catch {
                Logger.helper.error("Unable to write VM slot metrics to \(path.path): \(error)")
            }

            try? await Task.sleep(for: interval)
        }
    }

    /// Replaces the file in one step, so node_exporter never reads a partial file. The temporary
    /// file doesn't end in `.prom`, so the collector ignores it.
    func write(_ contents: String) throws {
        let temporaryPath = path.appendingPathExtension("tmp")
        try Data(contents.utf8).write(to: temporaryPath)

        guard rename(temporaryPath.path, path.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    static func render(slots: [VirtualMachineSlot]) -> String {
        var lines = [
            "# HELP hostmgr_vm_slot_state Whether the VM slot is in the given state.",
            "# TYPE hostmgr_vm_slot_state gauge"
        ]

        for slot in slots {
            for name in VirtualMachineSlot.State.allNames {
                let value = slot.state.name == name ? 1 : 0
                lines.append("hostmgr_vm_slot_state{slot=\"\(slot.role.rawValue)\",state=\"\(name)\"} \(value)")
            }
        }

        lines += [
            "# HELP hostmgr_vm_slot_available Whether the VM slot can accept a new VM.",
            "# TYPE hostmgr_vm_slot_available gauge"
        ]

        for slot in slots {
            lines.append("hostmgr_vm_slot_available{slot=\"\(slot.role.rawValue)\"} \(slot.isAvailable ? 1 : 0)")
        }

        lines += [
            "# HELP hostmgr_vm_slot_state_change_timestamp_seconds When the VM slot entered its current state.",
            "# TYPE hostmgr_vm_slot_state_change_timestamp_seconds gauge"
        ]

        for slot in slots {
            let timestamp = Int(slot.stateChangedAt.timeIntervalSince1970)
            lines.append("hostmgr_vm_slot_state_change_timestamp_seconds{slot=\"\(slot.role.rawValue)\"} \(timestamp)")
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
