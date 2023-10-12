import Foundation

/// The protocol used by the XPC framework to communicate between `hostmgr` and its helper.
@objc
public protocol HostmgrXPCProtocol {
    func startVM(withLaunchConfiguration config: String) async throws
    func stopVM(withHandle handle: String) async throws
    func stopAllVMs() async throws
}

public struct HostmgrXPCError: LocalizedError {

    private let errorMessage: String

    var localizedDescription: String {
        errorMessage
    }

    public var errorDescription: String? {
        errorMessage
    }

    public init(_ errorMessage: String) {
        self.errorMessage = errorMessage
    }
}
