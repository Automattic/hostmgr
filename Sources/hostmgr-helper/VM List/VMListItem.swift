import SwiftUI

struct VMListItem: View {

    @ObservedObject
    var slot: VirtualMachineSlot

    var body: some View {
        switch slot.status {
        case .empty: EmptyVMListItem(slot: slot)
        case .starting(let mvm, _):
            PendingVMListItem(
                launchConfiguration: mvm.config,
                slot: slot
            )
        case .running(let mvm):
            RunningVMListItem(
                launchConfiguration: mvm.config,
                ipAddress: mvm.ip ?? .any,
                slot: slot
            )
        case .stopping:
            EmptyVMListItem(slot: slot)
        case .crashed(let error):
            ErrorVMListItem(slot: slot, error: error)
        }
    }
}
