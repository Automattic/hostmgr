import SwiftUI
import Virtualization

struct VirtualMachineDisplayView: NSViewRepresentable {
    typealias NSViewType = VZVirtualMachineView

    let virtualMachine: ManagedVirtualMachine

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.virtualMachine = (virtualMachine as? VZManagedVirtualMachine)?.machine

        if #available(macOS 14.0, *) {
            view.automaticallyReconfiguresDisplay = true
        }
        return view
    }

    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
        // Nothing to do
    }
}
