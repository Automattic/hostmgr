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
    func startVM(withLaunchConfiguration config: String) async throws {
        Logger.helper.log("XPC Listener received start")

        let launchConfiguration = try LaunchConfiguration.unpack(config)
        try await vmHost.startVM(launchConfiguration:launchConfiguration)
    }

    func stopVM(withHandle handle: String) async throws {
        try await vmHost.stopVM(handle: handle)
    }

    func stopAllVMs() async throws {
        try await vmHost.stopAllVMs()
    }
}
