import SwiftUI

struct VMListItem: View {

    @ObservedObject
    var slot: VirtualMachineSlot

    var body: some View {
        switch slot.state {
        case .empty: EmptyVMListItem(slot: slot)
        case .starting(let launchConfiguration, _):
            PendingVMListItem(
                launchConfiguration: launchConfiguration,
                slot: slot
            )
        case .running(let mvm):
            RunningVMListItem(
                launchConfiguration: mvm.config,
                ipAddress: mvm.ip,
                slot: slot
            )
        case .stopping:
            EmptyVMListItem(slot: slot)
        case .crashed(let error):
            ErrorVMListItem(slot: slot, error: error)
        }
    }
}
