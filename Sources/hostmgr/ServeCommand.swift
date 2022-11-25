import Foundation
import ArgumentParser
import libhostmgr
import Embassy
import tinys3

struct ServeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the internal caching server"
    )

    func run() async throws {
        let router = try HttpRouter([
            .init(pattern: "^/s3/(?<bucketName>[^/]*)/$", endpoint: ListGitMirrorsEndpoint()),
            .init(pattern: "^/s3/(?<bucketName>[^/]*)/(?<path>.*)/$", endpoint: ListGitMirrorsEndpoint()),
            .init(pattern: "^/s3/(?<bucketName>[^/]*)/(?<path>.*)", endpoint: FetchGitMirrorEndpoint()),
        ])

        try HttpServer(router: router).run(on: 9876)
    }
}
