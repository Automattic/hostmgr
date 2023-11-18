import SwiftUI
import Virtualization
import Network
import libhostmgr
import OSLog

import Sentry

@main
struct HostMgrHelperApp: App {
    @AppStorage("showMenuBarExtra")
    private var showMenuBarExtra = true

    @ObservedObject
    private var vmHost = VMHost.shared

    private let vmManager = VMManager()

    private var serverTask: Task<Void, Error>!

    init() {
        SentrySDK.start(options: sentryOptions)

        // Do some cleanup before we get started
        do {
            try vmManager.resetVMWorkingDirectory()
        } catch {
            preconditionFailure(error.localizedDescription)
        }

        self.serverTask = Task {
            try await HostmgrServer(delegate: VMHost.shared).start()
        }
    }

    var body: some Scene {
        MenuBarExtra("Hostmgr Helper", systemImage: "play.desktopcomputer", isInserted: $showMenuBarExtra) {
            VStack(alignment: .leading) {
                VMListItem(slot: vmHost.primaryVMSlot)
                Divider().padding()
                VMListItem(slot: vmHost.secondaryVMSlot)
            }.padding()
        }.menuBarExtraStyle(.window)

        WindowGroup("VM View", id: "vm-view", for: VirtualMachineSlot.Role.self) { role in
            if let role = role.wrappedValue {
                VMWindowContent(role: role)
            } else {
                Text("Unable to define role")
            }
        }.defaultSize(width: 800, height: 600)
    }

    let sentryOptions: Sentry.Options = {
        var options = Sentry.Options()
        options.dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? ""
        options.releaseName = libhostmgr.hostmgrVersion
        options.enableSwizzling = false

        return options
    }()
}

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
