import SwiftUI
import libhostmgr

struct PendingVMListItem: View {
    let launchConfiguration: LaunchConfiguration
    let slot: VirtualMachineSlot

    var body: some View {
        VStack(alignment: .leading) {
            Text(slot.role.displayName)
                .font(.footnote)

            Text(launchConfiguration.name)
                .font(.title)
                .fontWeight(.medium)

            ProgressView()
        }
    }
}
