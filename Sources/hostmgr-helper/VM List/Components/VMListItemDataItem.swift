import SwiftUI

struct VMListItemDataItem: View {

    let key: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(key).font(.footnote)

            if let value {
                Text(value)
            } else {
                ProgressView().controlSize(.small)
            }

            Text("") // Used as a spacer
        }
    }
}
