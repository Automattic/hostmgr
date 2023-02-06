import Cocoa
import Virtualization

class VMViewController: NSViewController {

    override func loadView() {
        self.view = VZVirtualMachineView()
    }

    override func viewDidLoad() {
        self.view.translatesAutoresizingMaskIntoConstraints = true
        self.view.autoresizingMask = [.width, .height]
    }

    func present(virtualMachine: VZVirtualMachine) {
        guard let view = self.view as? VZVirtualMachineView else {
            abort()
        }

        view.virtualMachine = virtualMachine
        view.window?.title = virtualMachine.description
    }

    func dismissVirtualMachine() {
        guard let view = self.view as? VZVirtualMachineView else {
            abort()
        }

        view.virtualMachine = nil
    }
}
