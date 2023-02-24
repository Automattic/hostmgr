import Foundation
import Cocoa
import libhostmgr
import Virtualization
import Logging

@available(macOS 13.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    enum Errors: Error {
        case vmNotRunning
        case vmNotFound
    }

    private let listener = XPCService.createListener()

    private var activeVM: VZVirtualMachine?
    private let delegate = MacOSVirtualMachineDelegate()

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.trace("didFinishLaunching")

        self.listener.delegate = self
        self.listener.resume()

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

    @MainActor
    func launchVM(named name: String) async throws {
        logger.trace("Launching VM: \(name)")

        let virtualMachine = try VMLauncher.prepareVirtualMachine(named: name)
        virtualMachine.delegate = self.delegate

        self.viewController.present(virtualMachine: virtualMachine, named: name)

        self.activeVM = virtualMachine
        try await self.activeVM?.start()

        self.vmWindow.makeKeyAndOrderFront(nil)
        self.vmWindow.becomeFirstResponder()

        NSApp.setActivationPolicy(.regular)
    }

    @MainActor
    func stopVM() async throws {
        logger.trace("Stopping VM")

        guard let activeVM = self.activeVM else {
            logger.error("There is no active VM!")
            throw Errors.vmNotRunning
        }

        try await activeVM.stop()

        self.vmWindow.close()
        self.viewController.dismissVirtualMachine()

        self.activeVM = nil

        NSApp.setActivationPolicy(.prohibited)

        try libhostmgr.resetVMStorage()
    }
}

@available(macOS 13.0, *)
extension AppDelegate: NSXPCListenerDelegate {

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.trace("About to accept new connection")

        let exportedObject = XPCService(delegate: self)

        newConnection.exportedInterface = NSXPCInterface(with: HostmgrXPCProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()

        return true
    }
}

@available(macOS 13.0, *)
extension AppDelegate {
    @objc func didReceiveDebugNotification(_ notification: NSNotification) {
        guard let action = DebugActions(rawValue: notification.name.rawValue) else {
            return
        }

        Task {
            do {
                switch action {
                    case .startVM:
                        try await launchVM(named: "test")
                    case .stopVM:
                        try await stopVM()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

@available(macOS 13.0, *)
extension AppDelegate: XPCServiceDelegate {
    func service(shouldStartVMNamed name: String) async throws {
        print("Delegate received `shouldStartVM`")
        try await self.launchVM(named: name)
    }

    func serviceShouldStopVM() async throws {
        print("Delegate received `shouldStopVM`")
        try await self.stopVM()
    }
}
