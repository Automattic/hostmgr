import Foundation
import Network

struct RPCConstants {
    static let serviceDomain = "local."
    static let serviceName = "hostmgr-vm-relay"
    static let serviceType = "_hostmgr-relay._tcp"

    static var netService: NetService {
        NetService(domain: serviceDomain, type: serviceType, name: serviceName)
    }
}

@available(macOS 13.0, *)
public struct RPCServer {
    let listener: NWListener

    public init() throws {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 10

        let parameters = NWParameters(tls: .none, tcp: tcpOptions)

        var service = NWListener.Service(
            name: RPCConstants.serviceName,
            type: RPCConstants.serviceType
        )

        service.noAutoRename = true // Don't adjust the service name

        self.listener = try NWListener(service: service, using: parameters)
    }

    public func start() {
        listener.newConnectionHandler = { newConnection in
            /// We don't need to do anything here, we just don't want errors in the logs
            newConnection.start(queue: .main)
        }

        listener.start(queue: .main)
    }
}

public struct VMHostnameResolver {
    public static func resolve() async throws -> String {
        try await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.main.async {
                BonjourResolver.resolve(service: RPCConstants.netService) { continuation.resume(with: $0) }
            }
        }.0
    }
}

public struct VMResolver {
    public static func resolve() async throws {
        let browser = NWBrowser(
            for: .bonjour(type: RPCConstants.serviceType, domain: RPCConstants.serviceDomain),
            using: NWParameters()
        )

        await withCheckedContinuation { continuation in
            browser.browseResultsChangedHandler = { results, changes in
                guard let result = results.first else {
                    // Wait for another set of changes to come in
                    return
                }

                guard case let NWEndpoint.service(name, type, domain, _) = result.endpoint else {
                    // This somehow isn't our service, so wait for another set of changes
                    return
                }

                // Double-check that this is indeed our service
                guard
                    name == RPCConstants.serviceName,
                    type == RPCConstants.serviceType,
                    domain == RPCConstants.serviceDomain
                else {
                    return
                }

                continuation.resume(with: .success(()))
            }

            browser.start(queue: .main)
        }
    }
}

final class BonjourResolver: NSObject, NetServiceDelegate {
    typealias CompletionHandler = (Result<(String, Int), Error>) -> Void
    @discardableResult
    static func resolve(service: NetService, completionHandler: @escaping CompletionHandler) -> BonjourResolver {
        precondition(Thread.isMainThread)
        let resolver = BonjourResolver(service: service, completionHandler: completionHandler)
        resolver.start()
        return resolver
    }

    private init(service: NetService, completionHandler: @escaping CompletionHandler) {
        // We want our own copy of the service because we’re going to set a
        // delegate on it but `NetService` does not conform to `NSCopying` so
        // instead we create a copy by copying each property.
        let copy = NetService(domain: service.domain, type: service.type, name: service.name)
        self.service = copy
        self.completionHandler = completionHandler
    }

    deinit {
        // If these fire the last reference to us was released while the resolve
        // was still in flight.  That should never happen because we retain
        // ourselves on `start`.
        assert(self.service == nil)
        assert(self.completionHandler == nil)
        assert(self.selfRetain == nil)
    }

    private var service: NetService? = nil
    private var completionHandler: (CompletionHandler)? = nil
    private var selfRetain: BonjourResolver? = nil

    private func start() {
        precondition(Thread.isMainThread)
        guard let service = self.service else { fatalError() }
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Form a temporary retain loop to prevent us from being deinitialised
        // while the resolve is in flight.  We break this loop in `stop(with:)`.
        selfRetain = self
    }

    func stop() {
        self.stop(with: .failure(CocoaError(.userCancelled)))
    }

    private func stop(with result: Result<(String, Int), Error>) {
        precondition(Thread.isMainThread)
        self.service?.delegate = nil
        self.service?.stop()
        self.service = nil
        let completionHandler = self.completionHandler
        self.completionHandler = nil
        completionHandler?(result)

        selfRetain = nil
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let hostName = sender.hostName!
        let port = sender.port
        self.stop(with: .success((hostName, port)))
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let code = (errorDict[NetService.errorCode]?.intValue)
            .flatMap { NetService.ErrorCode.init(rawValue: $0) }
            ?? .unknownError
        let error = NSError(domain: NetService.errorDomain, code: code.rawValue, userInfo: nil)
        self.stop(with: .failure(error))
    }
}
