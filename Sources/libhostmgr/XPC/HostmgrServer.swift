import Foundation
import FlyingFox
import OSLog

public protocol HostmgrServerDelegate: AnyObject {
    func start(launchConfiguration: LaunchConfiguration) async throws
    func stop(handle: String) async throws
    func stopAll() async throws
}

protocol XPCRequest: Codable {
    static var method: HTTPMethod { get }
    static var path: String { get }
}

extension XPCRequest {
    func asUrlRequest(relativeTo baseURL: URL) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: Self.path))
        request.httpMethod = Self.method.rawValue

        if Self.method == .GET {
            return request
        }

        request.httpBody = try self.pack()
        request.timeoutInterval = 120
        return request
    }

    func pack() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func extract(from request: HTTPRequest) async throws -> Self {
        let data = try await request.bodyData
        return try unpack(data)
    }

    static func unpack(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

public struct VMServerPingRequest: XPCRequest {
    static let method: HTTPMethod = .GET
    static let path: String = "/"
}

public struct VMStartRequest: XPCRequest {
    static let method: HTTPMethod = .POST
    static let path: String = "/start"

    let launchConfiguration: LaunchConfiguration
}

public struct VMStopRequest: XPCRequest {
    static let method: HTTPMethod = .POST
    static let path: String = "/stop"

    let handle: String
}

public struct VMStopAllRequest: XPCRequest {
    static let method: HTTPMethod = .POST
    static let path: String = "/stop-all"
}

protocol XPCResponse: Codable {}
extension XPCResponse {

    func packed() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func unpack(_ data: Data) throws -> Self? {
        try? JSONDecoder().decode(Self.self, from: data)
    }
}

public struct InvalidRequestResponse: XPCResponse {
    let error: HostmgrError
}

public struct UnknownErrorResponse: XPCResponse {
    let error: String

    init(error: Error) {
        self.error = error.localizedDescription
    }
}

public struct HostmgrServer {
    private let server = HTTPServer(
        address: .loopback(port: 23604),
        timeout: 360 // How long to allow a handler to run before assuming it won't finish
    )

    private let delegate: HostmgrServerDelegate

    public init(delegate: HostmgrServerDelegate) {
        self.delegate = delegate
    }

    public func start() async throws {
        await self.server.appendRoute(HTTPRoute(method: .GET, path: "/"), handler: self.ping)
        await self.server.appendRoute(HTTPRoute(method: .POST, path: "/start"), handler: self.startVMHandler)
        await self.server.appendRoute(HTTPRoute(method: .POST, path: "/stop"), handler: self.stopVMHandler)
        await self.server.appendRoute(HTTPRoute(method: .POST, path: "/stop-all"), handler: self.stopAllVMs)

        try await self.server.start()
    }

    @Sendable
    func ping(request: HTTPRequest) async throws -> HTTPResponse {
        return HTTPResponse(statusCode: .ok, body: Data("Server is running".utf8))
    }

    @Sendable
    func startVMHandler(request: HTTPRequest) async throws -> HTTPResponse {
        Logger.helper.log("Received Start Request")

        do {
            let startRequest = try await VMStartRequest.extract(from: request)
            Logger.helper.log("Parsed launch configuration from request")

            try await self.delegate.start(launchConfiguration: startRequest.launchConfiguration)
            return HTTPResponse(statusCode: .ok)
        } catch let error as HostmgrError {
            return HTTPResponse(statusCode: .notAcceptable, body: try InvalidRequestResponse(error: error).packed())
        } catch let error {
            return HTTPResponse(statusCode: .internalServerError, body: try UnknownErrorResponse(error: error).packed())
        }
    }

    @Sendable
    func stopVMHandler(request: HTTPRequest) async throws -> HTTPResponse {
        let stopRequest = try await VMStopRequest.extract(from: request)
        try await self.delegate.stop(handle: stopRequest.handle)
        return HTTPResponse(statusCode: .ok)
    }

    @Sendable
    func stopAllVMs(request: HTTPRequest) async throws -> HTTPResponse {
        try await self.delegate.stopAll()
        return HTTPResponse(statusCode: .ok)
    }
}
