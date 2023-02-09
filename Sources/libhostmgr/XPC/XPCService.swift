import Foundation

@objc
public class XPCService: NSObject, HostmgrXPCProtocol {

    enum Errors: Error {
        case unableToCreateRemoteObjectProxy
    }

    private let delegate: XPCServiceDelegate

    public init(delegate: XPCServiceDelegate) {
        self.delegate = delegate
    }

    /// This method should never be called directly – it's the entry point into the `startVM` command when called via XPC
    public func startVM(named name: String, reply: @escaping (Error?) -> Void) {
        Task {
            do {
                try await self.delegate.service(shouldStartVMNamed: name)
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }

    /// This method should never be called directly – it's the entry point into the `stopVM` command when called via XPC
    public func stopVM(reply: @escaping (Error?) -> Void) {
        Task {
            do {
                try await self.delegate.serviceShouldStopVM()
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }

    /// The XPC service name – you must use this same string in your `LaunchAgent.plist` file's `MachServices` key
    ///
    /// Example:
    ///     <key>MachServices</key>
    ///     <dict>
    ///         <key>com.automattic.hostmgr.vmXPC</key>
    ///         <true/>
    ///     </dict>
    ///
    static let serviceName = "com.automattic.hostmgr.vmXPC"

    /// A helper that creates our XPC listener
    public static func createListener() -> NSXPCListener {
        NSXPCListener(machServiceName: serviceName )
    }
}

// MARK: – Public Call Sites
extension XPCService {
    /// Send a message to the XPC service running on the local machine, asking it to start the `named` virtual machine.
    public static func startVM(named name: String) async throws {
        let __protocol = try getProtocolObject()

        try await withCheckedThrowingContinuation { continuation in
            __protocol.startVM(named: name) { handle(error: $0, for: continuation) }
        }
    }

    /// Send a message to the XPC service running on the local machine, asking it to stop the running virtual machine.
    public static func stopVM() async throws {
        let __protocol = try getProtocolObject()

        try await withCheckedThrowingContinuation { continuation in
            __protocol.stopVM { handle(error: $0, for: continuation) }
        }
    }

    /// A DRY helper around processing XPC errors with Swift Concurrency
    private static func handle(error: Error?, for continuation: CheckedContinuation<Void, Error>) {
        if let error {
            continuation.resume(throwing: error)
            return
        }

        continuation.resume()
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
