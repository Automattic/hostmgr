import Foundation
import Embassy

protocol HttpEndpoint {
    func handle(request: HttpRequest) async throws -> HttpResponse
    func requestWasCompleted(_ request: HttpRequest) throws
}

struct HttpResponseCoordinator {

    typealias StartResponseCallback = (String, [(String, String)]) -> Void
    typealias SendBodyDataCallback = (Data) -> Void

    let startResponseCallback: StartResponseCallback
    let sendDataCallback: SendBodyDataCallback
    let eventLoop: EventLoop

    init(start: @escaping StartResponseCallback, send: @escaping SendBodyDataCallback, eventLoop: EventLoop) {
        self.startResponseCallback = start
        self.sendDataCallback = send
        self.eventLoop = eventLoop
    }

    func handle(_ request: HttpRequest, endpoint: HttpEndpoint) {
        Task {
            do {
                let response = try await endpoint.handle(request: request)
                try await self.sendResponse(response)
            } catch {
                self.sendServerError(error: error)
            }

            self.finalizeResponse()

            try? endpoint.requestWasCompleted(request)
        }
    }

    func sendResponse(_ response: HttpResponse) async throws {
        if let data = try (response as? HttpDataResponse)?.fetchData() {
            self.sendHeaders(statusCode: response.responseCode)
            self.sendData(data)
            return
        }

        try await (response as? StreamableHttpResponse)?.stream(
            headersCallback: { self.sendHeaders(statusCode: response.responseCode, headers: $0) },
            dataCallback: { self.sendData($0) }
        )
    }

    func sendResponseAndFinalize(_ response: HttpResponse) throws {
        if let data = try (response as? HttpDataResponse)?.fetchData() {
            self.sendData(data)
            return
        }
    }

    func sendHeaders(statusCode: Int, headers: [String: String] = [:]) {
        let string = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        self.eventLoop.call {
            self.startResponseCallback("\(statusCode) \(string)", headers.map { ($0.key, $0.value) })
        }
    }

    private func sendData(_ data: Data) {
        self.eventLoop.call {
            self.sendDataCallback(data)
        }
    }

    private func sendString(_ string: String) {
        self.sendData(Data(string.utf8))
    }

    private func finalizeResponse() {
        self.sendData(Data())
    }

    func sendNotFoundError() {
        self.sendHeaders(statusCode: 404)
        self.sendString(HTTPURLResponse.localizedString(forStatusCode: 404))
        self.finalizeResponse()
    }

    func sendServerError(error: Error? = nil) {
        self.sendHeaders(statusCode: 500)
        if let error {
            self.sendString(error.localizedDescription)
        }
        self.finalizeResponse()
    }
}
