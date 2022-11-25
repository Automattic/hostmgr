import Foundation
import libhostmgr
import tinys3

struct FetchGitMirrorEndpoint: HttpEndpoint {

    private let cacheRoot = Configuration.shared.gitMirrorDirectory
    private let temporaryDownloadUrl = FileManager.default.temporaryFilePath()

    func handle(request: HttpRequest) async throws -> HttpResponse {
        guard let credentials = try AWSCredentials.fromUserConfiguration() else {
            return HttpErrorResponse.serverError
        }

        guard
            let bucketName = request.params["bucketName"],
            let path = request.params["path"]
        else {
            return HttpErrorResponse.notFound
        }

        let manager = try S3Manager(
            bucket: bucketName,
            region: "us-east-2",
            credentials: credentials,
            endpoint: .accelerated
        )

        do {
            try await StatsRepository().recordResourceUsage(for: path, category: .gitMirror)

            if FileManager.default.fileExists(at: self.destination(with: path)) {
                return HttpStreamingFileResponse(responseCode: 200, filePath: self.destination(with: path))
            }

            guard let object = try await manager.lookupObject(atPath: path) else {
                return HttpErrorResponse.notFound
            }

            let url = manager.s3Client.signedDownloadUrl(forKey: object.key, in: bucketName, validFor: 60)
            return HttpStreamingDownloadResponse(responseCode: 200, source: url, destination: temporaryDownloadUrl)
        } catch {
            return HttpErrorResponse.serverError
        }
    }

    func requestWasCompleted(_ request: HttpRequest) throws {
        guard
            let path = request.params["path"],
            !FileManager.default.fileExists(atPath: path)
        else {
            return
        }

        try FileManager.default.createDirectory(
            at: destination(with: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try FileManager.default.copyItem(at: temporaryDownloadUrl, to: destination(with: path))
    }

    private func destination(with path: String) -> URL {
        return Configuration.shared.gitMirrorDirectory.appendingPathComponent(path)
    }
}
