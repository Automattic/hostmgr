import Foundation

public enum XPCResult: Int {
    case ok
    case error
}

public enum XPCError: Error {
    case unableToProvisionService
    case invalidResult
    case operationCouldNotBeCompleted
}

@objc
public protocol HostmgrXPCProtocol {
    func startVM(named name: String, reply: @escaping (Int) -> Void)
    func stopVM(named name: String, reply: @escaping (Int) -> Void)
}
