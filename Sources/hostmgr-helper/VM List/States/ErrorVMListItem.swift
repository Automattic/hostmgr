import SwiftUI

struct ErrorVMListItem: View {

    let slot: VirtualMachineSlot
    let error: Error

    var body: some View {
        VStack(alignment: .leading) {
            Text(slot.role.displayName).font(.footnote)

            Spacer()
            HStack {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error.localizedDescription)
                Spacer()
            }
            Spacer()
        }
    }
}
