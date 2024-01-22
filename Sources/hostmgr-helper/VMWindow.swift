import SwiftUI

struct VMWindowContent: View {

    @ObservedObject
    private var vmSlot: VirtualMachineSlot

    init(role: VirtualMachineSlot.Role) {
        self.vmSlot = VMHost.shared.vmSlot(for: role)
    }

    var body: some View {
        switch vmSlot.status {
        case .empty:  Text("VM not running")
        case .starting: ProgressView()
        case .running: VirtualMachineDisplayView(virtualMachine: vmSlot.virtualMachine!)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        case .stopping: ProgressView()
        case .crashed(let err): Text("VM Error: \(err.localizedDescription)")
        }
    }
}
