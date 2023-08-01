import Foundation
import Cocoa
import libhostmgr
import Virtualization
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate {

    enum Errors: Error {
        case vmNotRunning
        case vmNotFound
    }

    private let listener = XPCService.createListener()

    private var activeVM: VZVirtualMachine?

    @DIInjected
    private var vmManager: any VMManager

    let viewController = VMViewController()
    lazy var vmWindow: NSWindow = {
        var window = NSWindow(contentViewController: self.viewController)
        window.setFrame(CGRect(x: 0, y: 0, width: 800, height: 600), display: true)
        return window
    }()

    lazy var debugWindow: NSWindow = {
        var window = NSWindow(contentViewController: DebugViewController())
        window.setFrame(.init(origin: .zero, size: .init(width: 800, height: 600)), display: true)
        return window
    }()

    lazy var dockIcon: NSImage = {
        let iconPath = "/System/Library/CoreServices/UniversalControl.app/Contents/Resources/AppIcon.icns"
        let url = URL(fileURLWithPath: iconPath)
        return NSImage(contentsOf: url) ?? NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)!
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.helper.trace("didFinishLaunching")

        self.listener.delegate = self
        self.listener.resume()
        self.vmWindow.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.didReceiveDebugNotification(_:)),
            name: nil,
            object: nil
        )

        do {
            let arguments = try CLIArguments.parse()

            if arguments.debug {
                self.debugWindow.makeKeyAndOrderFront(nil)
            }
        } catch {
            print(CLIArguments.helpMessage())
            exit(1)
        }
    }

#if arch(arm64)
    @MainActor
    func launchVM(withLaunchConfiguration config: LaunchConfiguration) async throws {
        Logger.helper.trace("Launching VM: \(config.name, privacy: .public)")

        let virtualMachine = try await setupVirtualMachine(for: config)
        virtualMachine.delegate = self

        self.viewController.present(virtualMachine: virtualMachine, named: config.name)

        self.activeVM = virtualMachine
        try await self.activeVM?.start()

        self.vmWindow.makeKeyAndOrderFront(nil)
        self.vmWindow.becomeFirstResponder()

        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = self.dockIcon
    }

    @MainActor
    func stopVM() async throws {
        Logger.helper.trace("Stopping VM")

        guard let activeVM = self.activeVM else {
            Logger.helper.error("There is no active VM!")
            throw Errors.vmNotRunning
        }

        try await activeVM.stop()

        self.vmWindow.close()
        self.viewController.dismissVirtualMachine()

        self.activeVM = nil

        NSApp.setActivationPolicy(.prohibited)
        try await vmManager.resetVMWorkingDirectory()
    }

    func setupVirtualMachine(for launchConfiguration: LaunchConfiguration) async throws -> VZVirtualMachine {
        let configuration = try await prepareBundle(named: launchConfiguration.name).virtualMachineConfiguration()
        configuration.directorySharingDevices = [launchConfiguration.sharedDirectoryConfiguration]

        try configuration.validate()
        return VZVirtualMachine(configuration: configuration)
    }

    func prepareBundle(named name: String) async throws -> VMBundle {
        if try await vmManager.hasLocalVM(name: name, state: .packaged) {
            let tmpName = name + UUID().uuidString
            try await vmManager.cloneVM(from: name, to: tmpName)
            return try VMBundle.fromExistingBundle(at:  Paths.toAppleSiliconVM(named: tmpName))
        }

        if try await vmManager.hasLocalVM(name: name, state: .ready) {
            return try VMBundle.fromExistingBundle(at: Paths.toAppleSiliconVM(named: name))
        }

        preconditionFailure("Unable to find bundle named \(name)")
    }

#endif
}

extension AppDelegate: NSXPCListenerDelegate {

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        Logger.helper.trace("About to accept new connection")

        let exportedObject = XPCService(delegate: self)

        newConnection.exportedInterface = NSXPCInterface(with: HostmgrXPCProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()

        return true
    }
}

extension AppDelegate {
    @objc func didReceiveDebugNotification(_ notification: NSNotification) {
        guard
            let action = DebugActions(rawValue: notification.name.rawValue),
            let vmName = notification.object as? String
        else {
            return
        }

        #if arch(arm64)
        Task {
            do {
                switch action {
                case .startVM: try await launchVM(withLaunchConfiguration: LaunchConfiguration(name: vmName, sharedPaths: [
                    .init(source: URL(fileURLWithPath: "/Users/jkmassel/Downloads"))
                ]))
                case .stopVM: try await stopVM()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        #endif
    }
}

extension AppDelegate: XPCServiceDelegate {
    func service(withLaunchConfiguration config: LaunchConfiguration) async throws {
        #if arch(arm64)
        print("Delegate received `shouldStartVM`")
        try await self.launchVM(withLaunchConfiguration: config)
        #endif
    }

    func serviceShouldStopVM() async throws {
        #if arch(arm64)
        print("Delegate received `shouldStopVM`")
        do {
            try await self.stopVM()
        } catch Errors.vmNotRunning {
            // This is fine – we don't need to do anything for this case
        }
        #endif
    }
}

extension AppDelegate: VZVirtualMachineDelegate {
    public func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        NSApplication.shared.presentError(error)
    }

    public func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        self.vmWindow.close()
        self.viewController.dismissVirtualMachine()
        self.activeVM = nil
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Task {
            try await activeVM?.stop()

            self.viewController.dismissVirtualMachine()

            self.activeVM = nil

            NSApp.setActivationPolicy(.prohibited)

            try await vmManager.resetVMWorkingDirectory()
        }
    }
}
