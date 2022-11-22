import Foundation
import prlctl

public protocol ParallelsVMRepositoryProtocol {
    func lookupVMs() throws -> [VM]

    func lookupRunningVMs() throws -> [RunningVM]
    func lookupInvalidVMs() throws -> [InvalidVM]

    func lookupVM(withPrefix: String) throws -> VM?
    func lookupVM(byIdentifier id: String) throws -> VM?
}

public struct ParallelsVMRepository: ParallelsVMRepositoryProtocol {

    public init() {}

    public func lookupVMs() throws -> [VM] {
        try Parallels().lookupAllVMs()
    }

    public func lookupVMs(whereStatus status: VMStatus) throws -> [VM] {
        try lookupVMs().filter { $0.status == status }
    }

    public func lookupRunningVMs() throws -> [RunningVM] {
        try Parallels().lookupRunningVMs()
    }

    public func lookupInvalidVMs() throws -> [InvalidVM] {
        try Parallels().lookupInvalidVMs()
    }

    public func lookupVM(withPrefix prefix: String) throws -> VM? {
        return try Parallels()
            .lookupAllVMs()
            .filter { $0.name.hasPrefix(prefix) }
            .first
    }

    public func lookupVM(byIdentifier id: String) throws -> VM? {
       try Parallels()
            .lookupAllVMs()
            .first(where: { $0.name == id || $0.uuid == id })
    }
}
