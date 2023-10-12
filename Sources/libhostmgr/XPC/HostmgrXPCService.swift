import Foundation

@objc
public class HostmgrXPCService: NSObject {
    enum Errors: Error {
        case unableToCreateRemoteObjectProxy
    }

    /// The XPC service name – you must use this same string in your `LaunchAgent.plist` file's `MachServices` key
    ///
    /// Example:
    ///     <key>MachServices</key>
    ///     <dict>
    ///         <key>com.hostmgr.helper.xpc</key>
    ///         <true/>
    ///     </dict>
    ///
    static let serviceName = "com.hostmgr.helper.xpc"

    /// A helper that creates our XPC listener
    public static func createListener() -> NSXPCListener {
        NSXPCListener(machServiceName: serviceName )
    }
}

// MARK: – Public Call Sites
extension HostmgrXPCService {


    /// Send a message to the XPC service running on the local machine, asking it to start the `named` virtual machine.
    public static func startVM(withLaunchConfiguration config: LaunchConfiguration) async throws {
        let protocolObject = try getProtocolObject()
        let configuration = try config.packed()

        try await protocolObject.startVM(withLaunchConfiguration: configuration)
    }

    /// Send a message to the XPC service running on the local machine, asking it to stop the running virtual machine.
    public static func stopVM(handle: String) async throws {
        let protocolObject = try getProtocolObject()
        try await protocolObject.stopVM(withHandle: handle)
    }

    public static func stopAllVMs() async throws {
        let protocolObject = try getProtocolObject()
        try await protocolObject.stopAllVMs()

    }

    /// A DRY helper around setting up the XPC Connection
    private static func getProtocolObject() throws -> HostmgrXPCProtocol {
        let connection = NSXPCConnection(machServiceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: HostmgrXPCProtocol.self)
        connection.resume()

        guard let connection = connection.remoteObjectProxy as? HostmgrXPCProtocol else {
            throw Errors.unableToCreateRemoteObjectProxy
        }

        return connection
    }
}
