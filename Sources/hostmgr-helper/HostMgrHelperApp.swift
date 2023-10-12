import SwiftUI
import Virtualization
import Network
import libhostmgr

@main
struct HostMgrHelperApp: App {
    @AppStorage("showMenuBarExtra")
    private var showMenuBarExtra = true

    @ObservedObject
    private var vmHost = VMHost.shared

    private let listener: HostmgrXPCListener

    @DIInjected
    private var vmManager: any VMManager

    init() {
        self.listener = HostmgrXPCListener(vmHost: VMHost.shared)

        // Do some cleanup before we get started
        do {
            try vmManager.resetVMWorkingDirectory()
        } catch {
            preconditionFailure(error.localizedDescription)
        }

        // Now we're ready to start listening for commands
        self.listener.resume()
    }

    var body: some Scene {
        MenuBarExtra("Hostmgr Helper", systemImage: "play.desktopcomputer", isInserted: $showMenuBarExtra) {
            VStack(alignment: .leading) {
                VMListItem(slot: vmHost.primaryVMSlot, number: 1)
                Divider().padding()
                VMListItem(slot: vmHost.secondaryVMSlot, number: 2)
            }.padding()
        }.menuBarExtraStyle(.window)
    }
}

struct EmptyVMListItem: View {
    let number: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("Slot \(number)").font(.footnote)

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

struct ErrorVMListItem: View {
    let number: Int

    let error: Error

    var body: some View {
        VStack(alignment: .leading) {
            Text("Slot \(number)").font(.footnote)

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

struct PendingVMListItem: View {
    let number: Int
    let launchConfiguration: LaunchConfiguration

    var body: some View {
        VStack(alignment: .leading) {
            Text("Slot \(number)")
                .font(.footnote)

            Text(launchConfiguration.name)
                .font(.title)
                .fontWeight(.medium)

            ProgressView()
        }
    }
}

struct RunningVMListItem: View {
    let number: Int
    let launchConfiguration: LaunchConfiguration
    let ipAddress: IPv4Address

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

    func shutdown() {
        Task {
            try await slot.stopVirtualMachine()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Slot \(number)")
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

struct VMListItem: View {

    @ObservedObject
    var slot: VirtualMachineSlot

    let number: Int

    var body: some View {
        switch slot.status {
            case .empty:
            EmptyVMListItem(number: number)
            case .starting(let launchConfiguration):
            PendingVMListItem(number: number, launchConfiguration: launchConfiguration)
            case .running(let launchConfiguration, let ipAddress):
            RunningVMListItem(number: number, launchConfiguration: launchConfiguration, ipAddress: ipAddress, slot: slot)
            case .stopping:
            EmptyVMListItem(number: number)
            case .crashed(let error):
            ErrorVMListItem(number: number, error: error)
        }
    }
}

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
