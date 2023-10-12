import Foundation

struct HostmgrClient {

    enum XPCError: Error {
        case unknown(String)

        var errorDescription: String {
            switch self {
                case .unknown(let message): return message
            }
        }
    }

    private static let baseURL = URL(string: "http://localhost:23604")!

    static func start(launchConfiguration: LaunchConfiguration) async throws {
        try await perform(request: VMStartRequest(launchConfiguration: launchConfiguration))
    }

    static func stop(handle: String) async throws {
        try await perform(request: VMStopRequest(handle: handle))
    }

    static func stopAllVMs() async throws {
        try await perform(request: VMStopAllRequest())
    }

    static func perform(request: XPCRequest) async throws {
        let request = try request.asUrlRequest(relativeTo: baseURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as! HTTPURLResponse).statusCode

        // Bail early if we don't need to handle errors
        guard statusCode != 200 else {
            return
        }

        if let response = try InvalidRequestResponse.unpack(data) {
            throw response.error
        }

        if let response = try UnknownErrorResponse.unpack(data) {
            throw HostmgrError.xpcError(response.error)
        }

        throw HostmgrError.helperIsMissing(baseURL)
    }
}