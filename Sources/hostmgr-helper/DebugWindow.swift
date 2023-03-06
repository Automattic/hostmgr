import SwiftUI
import libhostmgr

class DebugViewController: NSViewController {
    override func loadView() {
        self.view = NSHostingView(rootView: DebugWindow())
    }
}

enum DebugActions: String {
    case startVM = "start-vm"
    case stopVM = "stop-vm"

    var name: NSNotification.Name {
        NSNotification.Name(self.rawValue)
    }
}

struct DebugWindow: View {

    @State private var VMs: [String]
    @State private var selectedVM: String

    init() {
        let vmList = try! LocalVMRepository().list().filter { $0.state != .compressed }.map { $0.basename }
        self.VMs = vmList
        self.selectedVM = vmList.first!
    }

    var body: some View {
        Form {
            Section {
                Picker("VM", selection: $selectedVM) {
                    ForEach(self.VMs, id: \.self) {
                        Text($0)
                    }
                }

                Button("Start VM") {
                    NotificationCenter.default.post(name: DebugActions.startVM.name, object: self.selectedVM)
                }
            }

            Section {
                Button("Stop VM") {
                    NotificationCenter.default.post(name: DebugActions.stopVM.name, object: self.selectedVM)
                }
            }
        }.padding()
    }
}
