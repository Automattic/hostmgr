import Foundation

public protocol XPCServiceDelegate {
    func service(shouldStartVMNamed name: String) async throws
    func service(shouldStopVMNamed name: String) async throws
}

@objc
public class XPCService: NSObject, HostmgrXPCProtocol {

    private let delegate: XPCServiceDelegate

    public init(delegate: XPCServiceDelegate) {
        self.delegate = delegate
    }

    public func startVM(named name: String, reply: @escaping (Int) -> Void) {
        Task {
            do {
                try await self.delegate.service(shouldStartVMNamed:name)
                reply(XPCResult.ok.rawValue)
            } catch {
                reply(XPCResult.error.rawValue)
            }
        }
    }

    public func stopVM(named name: String, reply: @escaping (Int) -> Void) {
        Task {
            do {
                try await self.delegate.service(shouldStopVMNamed: name)
                reply(XPCResult.ok.rawValue)
            } catch {
                reply(XPCResult.error.rawValue)
            }
        }
    }

    static let serviceName = "com.automattic.hostmgr.vmXPC"

    public static func createListener() -> NSXPCListener {
        NSXPCListener(machServiceName: serviceName )
    }

    @MainActor
    public static func startVM(named name: String) async throws {
        let connection = getConnection()

        let prot = connection.remoteObjectProxy as! HostmgrXPCProtocol

        try await withCheckedThrowingContinuation { continuation in
            prot.startVM(named: name) { reply in
                debugPrint(reply)
                continuation.resume()
            }
        }
    }

    public static func stopVM(named name: String) async throws {
//        try await perform { $0.stopVM(named: name, reply: $1) }
    }

    private static func getConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: HostmgrXPCProtocol.self)
        connection.resume()

        return connection
    }

//    static func perform(
//        _ action: @escaping (HostmgrXPCProtocol, @escaping (Int) -> Void) throws -> Void
//    ) async throws {
//        let connection = NSXPCConnection(machServiceName: serviceName)
//        connection.remoteObjectInterface = NSXPCInterface(with: HostmgrXPCProtocol.self)
//        connection.resume()
//
//        return try await withCheckedThrowingContinuation { continuation in
//            let untypedService = connection.remoteObjectProxyWithErrorHandler { error in
//                continuation.resume(with: .failure(error))
//            }
//
//            guard let service = untypedService as? HostmgrXPCProtocol else {
//                continuation.resume(with: .failure(XPCError.unableToProvisionService))
//                return
//            }
//
//            do {
//                try action(service) { result in
//                    guard result == XPCResult.ok.rawValue else {
//                        continuation.resume(throwing: XPCError.invalidResult)
//                        return
//                    }
//
//                    continuation.resume()
//                }
//            } catch {
//                continuation.resume(throwing: error)
//            }
//        }
//    }
}
