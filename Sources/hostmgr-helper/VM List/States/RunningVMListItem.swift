import SwiftUI
import Network

import libhostmgr

struct RunningVMListItem: View {
    let launchConfiguration: LaunchConfiguration
    let ipAddress: IPv4Address

    @Environment(\.openWindow)
    var openWindow: OpenWindowAction

    @ObservedObject
    var slot: VirtualMachineSlot

    func openVNCSession() {
        let vncURL = URL(string: "vnc://\(ipAddress.debugDescription)")!
        NSWorkspace.shared.open(vncURL)
    }

    func openSSHSession() {
        let sshURL = URL(string: "ssh://\(ipAddress.debugDescription)")!
        NSWorkspace.shared.open(sshURL)
    }

    func openVMWindow() {
        self.openWindow(id: "vm-view", value: slot.role)
    }

    func shutdown() {
        Task {
            try await slot.stopVirtualMachine()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(slot.role.displayName)
                .font(.footnote)

            Text(launchConfiguration.name)
                .font(.title)
                .fontWeight(.medium)

            VMListItemDataItem(key: "Handle", value: launchConfiguration.handle)
            VMListItemDataItem(key: "IP Address", value: ipAddress.debugDescription)

            HStack(alignment: .top) {
                Button(action: self.openVNCSession, label: {
                    Label("VNC", systemImage: "play.display")
                })

                Button(action: self.openVMWindow, label: {
                    Label("View", systemImage: "display")
                })

                Button(action: self.openSSHSession, label: {
                    Label("SSH", systemImage: "terminal").foregroundStyle(.white)
                })

                Button(action: self.shutdown, label: {
                    Label("Stop", systemImage: "stop.circle").foregroundStyle(.white)
                })
            }.frame(maxWidth: .infinity)
        }

    }
}
