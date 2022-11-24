import Foundation
import libhostmgr
import tinys3

struct ListGitMirrorsEndpoint: HttpEndpoint {

    struct ServerFile: Codable {
        let name: String // We use `name` instead of `key` here for backward compatibility
        let size: Int
        let lastModifiedAt: Date

        init(_ object: S3Object) {
            self.name = object.key
            self.size = object.size
            self.lastModifiedAt = object.lastModifiedAt
        }
    }

    func handle(request: HttpRequest) async throws -> HttpResponse {
        guard let credentials = try AWSCredentials.fromUserConfiguration() else {
            return HttpErrorResponse.serverError
        }

        guard let bucketName = request.params["bucketName"] else {
            return HttpErrorResponse.notFound
        }

        let manager = try S3Manager(
            bucket: bucketName,
            region: "us-east-2",
            credentials: credentials,
            endpoint: .accelerated
        )

        let objects = try await manager.listObjects(startingWith: request.params["path"])
            .map(ServerFile.init)
            .filter { !$0.name.hasSuffix("/") } // Don't include S3 directory paths

        return HttpCodableResponse(rootObject: objects)
    }

    func requestWasCompleted(_ request: HttpRequest) throws {

    }
}
