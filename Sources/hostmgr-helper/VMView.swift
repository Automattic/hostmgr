import SwiftUI
import Virtualization

struct VMView: NSViewRepresentable {
    typealias NSViewType = VZVirtualMachineView

    let virtualMachine: VZVirtualMachine

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.virtualMachine = virtualMachine
        if #available(macOS 14.0, *) {
            view.automaticallyReconfiguresDisplay = true
        }
        return view
    }

    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
        // Nothing to do
    }
}
