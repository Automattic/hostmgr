import SwiftUI

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
    var body: some View {
        VStack {
            Button("Start VM") {
                NotificationCenter.default.post(name: DebugActions.startVM.name, object: nil)
            }

            Button("Stop VM") {
                NotificationCenter.default.post(name:  DebugActions.stopVM.name, object: nil)
            }
        }.padding()
    }
}
