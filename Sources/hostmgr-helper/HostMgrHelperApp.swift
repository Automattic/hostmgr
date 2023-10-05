import SwiftUI
import Virtualization
import libhostmgr

@main
struct HostMgrHelperApp: App {
    @AppStorage("showMenuBarExtra")
    private var showMenuBarExtra = true

    @ObservedObject
    private var vmHost: VMHost

    private let listener: HostmgrXPCListener

    @DIInjected
    private var vmManager: any VMManager

    init() {
        let vmHost = VMHost()
        self.vmHost = vmHost
        self.listener = HostmgrXPCListener(vmHost: vmHost)

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
                VMListItem(vm: vmHost.primaryVM, number: 1, vmHost: self.vmHost)
                Divider().padding()
                VMListItem(vm: vmHost.secondaryVM, number: 2, vmHost: self.vmHost)
            }.padding()
        }.menuBarExtraStyle(.window)
    }
}

struct VMListItem: View {

    @ObservedObject
    var vm: VMHost.VirtualMachineSlot

    let number: Int

    let vmHost: VMHost

    @State
    var isShuttingDown: Bool = false

    func openVNCSession() {
        let vncURL = URL(string: "vnc://\(self.vm.ipAddress!.debugDescription)")!
        NSWorkspace.shared.open(vncURL)
    }

    func openSSHSession() {
        let sshURL = URL(string: "ssh://\(self.vm.ipAddress!.debugDescription)")!
        NSWorkspace.shared.open(sshURL)
    }

    func shutdown() {
        Task {
            if let handle = self.vm.handle {
                self.isShuttingDown = true
                try await self.vmHost.stopVM(handle: handle)
                self.isShuttingDown = false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Slot \(number)")
                .font(.footnote)

            if let name = vm.name, let handle = vm.handle {
                    Text(name)
                        .font(.title)
                        .fontWeight(.medium)

                    VMListItemDataItem(key: "Handle", value: handle)
                    VMListItemDataItem(key: "IP Address", value: vm.ipAddress?.debugDescription)

                    HStack(alignment: .top) {
                        Button(action: self.openVNCSession, label: {
                            Label("VNC", systemImage: "play.display")
                                .foregroundStyle(.white)
                                .disabled(vm.ipAddress == nil)
                        }).disabled(vm.ipAddress == nil)

                        Button(action: self.openSSHSession, label: {
                            Label("SSH", systemImage: "terminal")
                                .foregroundStyle(.white)
                                .disabled(vm.ipAddress == nil)
                        }).disabled(vm.ipAddress == nil)

                        Button(action: self.shutdown, label: {
                            if self.isShuttingDown {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Stop", systemImage: "stop.circle").foregroundStyle(.white)
                            }
                        })
                    }.frame(maxWidth: .infinity)
            } else {
                HStack {
                    Spacer()
                    Text("No VM Running").font(.title2)
                    Spacer()
                }
            }
        }
    }
}

extension String: Identifiable {
    public var id: String {
        return self
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
