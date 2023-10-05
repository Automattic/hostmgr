import Foundation

/// The protocol used by the XPC framework to communicate between `hostmgr` and its helper.
@objc
public protocol HostmgrXPCProtocol {
    func startVM(withLaunchConfiguration config: String, reply: @escaping (String?) -> Void)
    func stopVM(withHandle handle: String, reply: @escaping (String?) -> Void)
    func stopAllVMs(reply: @escaping (String?) -> Void)
}

public struct HostmgrXPCError: LocalizedError {

    private let errorMessage: String

    var localizedDescription: String {
        errorMessage
    }

    public var errorDescription: String? {
        errorMessage
    }

    init(_ errorMessage: String) {
        self.errorMessage = errorMessage
    }
}
