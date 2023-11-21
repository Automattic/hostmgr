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
