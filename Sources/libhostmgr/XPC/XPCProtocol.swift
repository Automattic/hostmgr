import Foundation

/// The various errors that can happen across the XPC channel
public enum XPCError: Error {
    case unableToProvisionService
    case invalidResult
    case operationCouldNotBeCompleted
}

/// The protocol used by the XPC framework to communicate between `hostmgr` and its helper.
@objc
public protocol HostmgrXPCProtocol {
    func startVM(named name: String, reply: @escaping (Error?) -> Void)
    func stopVM(reply: @escaping (Error?) -> Void)
}

/// A delegate protocol for actions triggered by XPC – the delegate most likely owns the `XPCService` instance,
/// and should handle its actions appropriately.
public protocol XPCServiceDelegate: AnyObject {
    func service(shouldStartVMNamed name: String) async throws
    func serviceShouldStopVM() async throws
}
