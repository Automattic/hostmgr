import Foundation
import Embassy

struct HttpServer {

    private let loop: SelectorEventLoop
    private let router: HttpRouter

    init(router: HttpRouter) throws{
        self.loop = try SelectorEventLoop(selector: try KqueueSelector())
        self.router = router
    }

    func run(on port: Int) throws {
        let server = DefaultHTTPServer(eventLoop: loop, port: port, app: self.entrypoint)
        try server.start()
        loop.runForever()
    }

    private func entrypoint(
        env: [String: Any],
        startResponse: @escaping HttpResponseCoordinator.StartResponseCallback,
        sendBody: @escaping HttpResponseCoordinator.SendBodyDataCallback
    ) {
        let loop = env["embassy.event_loop"] as! EventLoop
        let responseCoordinator = HttpResponseCoordinator(start: startResponse, send: sendBody, eventLoop: loop)

        guard let pathValue = env["PATH_INFO"] else {
            do {
                try responseCoordinator.sendResponseAndFinalize(HttpErrorResponse.invalidRequest)
            } catch {
                responseCoordinator.sendServerError()
            }
            return
        }

        let path = String(describing: pathValue)

        guard let route = self.router.route(for: path) else {
            responseCoordinator.sendServerError()
            return
        }

        let request = HttpRequest(path: path, params: route.params(path: path))
        responseCoordinator.handle(request, endpoint: route.endpoint)
    }
}
