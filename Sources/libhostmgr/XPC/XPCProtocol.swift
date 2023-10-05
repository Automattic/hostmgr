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
    func startVM(withLaunchConfiguration config: String, reply: @escaping (Error?) -> Void)
    func stopVM(withHandle handle: String, reply: @escaping (Error?) -> Void)
    func stopAllVMs(reply: @escaping (Error?) -> Void)
}
