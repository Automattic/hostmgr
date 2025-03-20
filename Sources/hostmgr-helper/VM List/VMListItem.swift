import SwiftUI

struct VMListItem: View {

    @ObservedObject
    var slot: VirtualMachineSlot

    var body: some View {
        switch slot.state {
        case .empty: EmptyVMListItem(slot: slot)
        case .starting(let mvm, _):
            PendingVMListItem(
                launchConfiguration: mvm.config,
                slot: slot
            )
        case .running(let virtualMachine):
            RunningVMListItem(
                launchConfiguration: virtualMachine.config,
                ipAddress: virtualMachine.ip,
                slot: slot
            )
        case .stopping:
            EmptyVMListItem(slot: slot)
        case .crashed(let error):
            ErrorVMListItem(slot: slot, error: error)
        }
    }
}
