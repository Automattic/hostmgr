import Foundation
import libhostmgr

struct HttpLiteralRoute {
    let pattern: String
    let endpoint: HttpEndpoint
}

struct HttpRoute {
    let pattern: NSRegularExpression
    let endpoint: HttpEndpoint

    init(literal: HttpLiteralRoute) throws {
        self.pattern = try NSRegularExpression(pattern: literal.pattern)
        self.endpoint = literal.endpoint
    }

    // Does this route match the given `path`?
    func matches(path: String) -> Bool {
        self.pattern.numberOfMatches(in: path, range: NSMakeRange(0, path.count)) == 1
    }

    // Extract any named parameters from the path
    func params(path: String) -> [String: String] {
        return pattern.namedMatches(in: path)
    }
}

struct HttpRouter {
    let routes: [HttpRoute]

    init(routes: [HttpRoute]) {
        self.routes = routes
    }

    init(_ literalRoutes: [HttpLiteralRoute]) throws {
        self.routes = try literalRoutes.map(HttpRoute.init)
    }

    func route(for path:  String) -> HttpRoute? {
       return routes.first { $0.matches(path: path) }
    }
}
