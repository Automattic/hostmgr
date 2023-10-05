import Foundation
import Virtualization
import libhostmgr
import OSLog

class HostmgrXPCListener: NSObject, NSXPCListenerDelegate {
    private let serviceListener: NSXPCListener
    private let vmHost: VMHost

    init(vmHost: VMHost) {
        self.serviceListener = HostmgrXPCService.createListener()
        self.vmHost = vmHost

        super.init()

        self.serviceListener.delegate = self
    }

    /// Start listening for XPC messages
    ///
    public func resume() {
        self.serviceListener.resume()
    }

    /// Handle incoming XPC messages
    ///
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HostmgrXPCProtocol.self)
        newConnection.exportedObject = self //This object implements `HostmgrXPCProtocol` and should respond to messages
        newConnection.resume()

        return true
    }
}

extension HostmgrXPCListener: HostmgrXPCProtocol {
    func startVM(withLaunchConfiguration config: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let launchConfiguration = try LaunchConfiguration.from(string: config)
                try await vmHost.startVM(launchConfiguration:launchConfiguration)
                reply(nil)

            } catch {
                Logger.helper.error("\(error.localizedDescription, privacy: .public)")
                reply(error.localizedDescription)
            }
        }
    }

    func stopVM(withHandle handle: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                try await vmHost.stopVM(handle: handle)
                reply(nil)
            } catch {
                reply(error.localizedDescription)
            }
        }
    }

    func stopAllVMs(reply: @escaping (String?) -> Void) {
        Task {
            do {
                try await vmHost.stopAllVMs()
                reply(nil)
            } catch {
                reply(error.localizedDescription)
            }
        }
    }

}
