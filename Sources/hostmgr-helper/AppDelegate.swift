import Foundation
import Cocoa
import libhostmgr
import Virtualization

@available(macOS 13.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {

    enum Errors: Error {
        case vmNotRunning
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
        print("didFinishLaunching")
        self.listener.delegate = self
        self.listener.resume()

        NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveDebugNotification(_:)), name: nil, object: nil)

        do {
            let arguments = try CLIArguments.parse()

            if arguments.debug {
                self.debugWindow.makeKeyAndOrderFront(nil)
            }
        } catch {
            print(CLIArguments.helpMessage())
            exit(0)
        }
    }

    @MainActor
    func launchVM(named name: String) async throws {
        let bundle = try VMBundle.fromExistingBundle(at: Paths.toAppleSiliconVM(named: name))
        let configuration = try bundle.virtualMachineConfiguration()
        try configuration.validate()

        let virtualMachine = VZVirtualMachine(configuration: configuration)
        virtualMachine.delegate = self.delegate
        self.viewController.present(virtualMachine: virtualMachine)

        self.activeVM = virtualMachine
        try await self.activeVM?.start()

        self.vmWindow.makeKeyAndOrderFront(nil)
        self.vmWindow.becomeFirstResponder()

        NSApp.setActivationPolicy(.regular)
    }

    @MainActor
    func stopVM() async throws {
        guard let activeVM = self.activeVM else {
            print("There is no active VM!")
            throw Errors.vmNotRunning
        }

        try await activeVM.stop()

        self.vmWindow.close()
        self.viewController.dismissVirtualMachine()

        self.activeVM = nil

        NSApp.setActivationPolicy(.prohibited)
    }
}

@available(macOS 13.0, *)
extension AppDelegate: NSXPCListenerDelegate {

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        print("About to accept new connection")

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
        try await self.launchVM(named: name)
    }

    func serviceShouldStopVM() async throws {
        try await self.stopVM()
    }
}
