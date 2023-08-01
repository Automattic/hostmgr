import SwiftUI
import libhostmgr

class DebugViewController: NSViewController {

    @DIInjected
    var vmManager: any VMManager

    override func loadView() {
        Task {
            do {
                let vmList = try await vmManager.list().map(\.name)
                self.view = NSHostingView(rootView: DebugWindow(vmList: vmList))
            } catch {
                self.view = NSHostingView(rootView: NoVMsView())
            }
        }
    }
}

enum DebugActions: String {
    case startVM = "start-vm"
    case stopVM = "stop-vm"

    var name: NSNotification.Name {
        NSNotification.Name(self.rawValue)
    }
}

struct NoVMsView: View {
    var body: some View {
        Text("No VMs found")
    }
}

struct DebugWindow: View {

    @State private var VMs: [String]
    @State private var selectedVM: String

    init(vmList: [String]) {
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
