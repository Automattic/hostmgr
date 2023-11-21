import SwiftUI

struct VMListItem: View {

    @ObservedObject
    var slot: VirtualMachineSlot

    var body: some View {
        switch slot.status {
        case .empty: EmptyVMListItem(slot: slot)
        case .starting(let launchConfiguration):
            PendingVMListItem(
                launchConfiguration: launchConfiguration,
                slot: slot
            )
        case .running(let launchConfiguration, let ipAddress):
            RunningVMListItem(
                launchConfiguration: launchConfiguration,
                ipAddress: ipAddress,
                slot: slot
            )
        case .stopping:
            EmptyVMListItem(slot: slot)
        case .crashed(let error):
            ErrorVMListItem(slot: slot, error: error)
        }
    }
}
