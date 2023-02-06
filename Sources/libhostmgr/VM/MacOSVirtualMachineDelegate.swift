import Virtualization

public class MacOSVirtualMachineDelegate: NSObject, VZVirtualMachineDelegate {
    public func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        NSLog("Virtual machine did stop with error: \(error.localizedDescription)")
        exit(-1)
    }

    public func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        NSLog("Guest did stop virtual machine.")
    }
}
