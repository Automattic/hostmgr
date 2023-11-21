import SwiftUI

struct EmptyVMListItem: View {

    let slot: VirtualMachineSlot

    var body: some View {
        VStack(alignment: .leading) {
            Text(slot.role.displayName).font(.footnote)

            Spacer()
            HStack {
                Spacer()
                Text("No VM Running").font(.title2)
                Spacer()
            }
            Spacer()
        }
    }
}
