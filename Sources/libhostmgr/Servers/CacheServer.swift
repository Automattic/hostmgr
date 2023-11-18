import Foundation
import tinys3

public struct CacheServerFile: Codable {
    public let name: String
    public let size: Int
    public let path: String
    public let lastModifiedAt: Date
    public let mode: Int
    public let isDirectory: Bool
    public let isSymlink: Bool

    enum CodingKeys: String, CodingKey {
        case name = "name"
        case size = "size"
        case path = "url"
        case mode = "mode"
        case lastModifiedAt = "mod_time"
        case isDirectory = "is_dir"
        case isSymlink = "is_symlink"
    }

    public static func < (lhs: CacheServerFile, rhs: CacheServerFile) -> Bool {
        lhs.name < rhs.name
    }

    public var basename: String {
        name
    }

    var asRemoteFile: RemoteFile {
        RemoteFile(size: size, path: path, lastModifiedAt: lastModifiedAt)
    }
}

public struct CacheServer: ReadableRemoteFileProvider {

    public static let cache = CacheServer(path: "/cache")
    public static let gitMirrors = CacheServer(path: "/git-mirrors")
    public static let vmImages = CacheServer(path: "/vm-images")

    let session = URLSession(configuration: .default)

    let basePath: String

    var baseURL: URL? {
        let hostname = Configuration.shared.cacheServerHostname
        let ipAddress = Configuration.shared.cacheServerAddress

        guard hostname != nil && ipAddress != nil else {
            return nil
        }

        if needsHostHeader, let ipAddress {
            return URL(string: "http://\(ipAddress.debugDescription)")?.appendingPathComponent(basePath)
        }

        guard let hostname else {
            return nil
        }

        return URL(string: "http://\(hostname)")?.appendingPathComponent(basePath)
    }

    var needsHostHeader: Bool {
        return Configuration.shared.cacheServerAddress != nil
    }

    public init(path: String) {
        self.basePath = path
    }

    public func hasFile(named name: String) async throws -> Bool {
        guard let url = baseURL?.appendingPathComponent(name) else {
            return false
        }

        return try await HEAD(url: url).statusCode == 200
    }

    func parseFileData(_ data: Data) throws -> [RemoteFile] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CacheServerFile].self, from: data).map { $0.asRemoteFile }
    }

    public func downloadFile(
        named name: String,
        to destination: URL,
        progress: @escaping ProgressCallback)
    async throws {
        guard let url = baseURL?.appendingPathComponent(name) else {
            preconditionFailure("Don't try to download a file without checking if it exists first")
        }

        var request = URLRequest(url: url)

        if needsHostHeader, let hostname = Configuration.shared.cacheServerHostname {
            request.addValue(hostname, forHTTPHeaderField: "Host")
        }

        let downloadPath = try await DownloadOperation(request: request).start(progressCallback: progress)

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try FileManager.default.moveItem(at: downloadPath, to: destination)
    }

    func HEAD(url: URL) async throws -> HTTPURLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        if needsHostHeader, let hostname = Configuration.shared.cacheServerHostname {
            request.addValue(hostname, forHTTPHeaderField: "Host")
        }

        let (_, response) = try await session.data(for: request)

        // swiftlint:disable force_cast
        return response as! HTTPURLResponse
        // swiftlint:enable force_cast
    }

    func LIST(url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        if needsHostHeader, let hostname = Configuration.shared.cacheServerHostname {
            request.addValue(hostname, forHTTPHeaderField: "Host")
        }

        let (data, response) = try await session.data(for: request)

        // swiftlint:disable force_cast
        return (data, response as! HTTPURLResponse)
        // swiftlint:enable force_cast
    }
}

class DownloadOperation: NSObject {

    private let request: URLRequest
    private let urlSessionConfiguration: URLSessionConfiguration
    private lazy var session: URLSession = URLSession(
        configuration: self.urlSessionConfiguration,
        delegate: self,
        delegateQueue: nil
    )
    private lazy var task: URLSessionDownloadTask = session.downloadTask(with: self.request)

    private var downloadContinuation: CheckedContinuation<URL, Error>!
    private var progressCallback: ProgressCallback?
    private var startDate: Date!

    init(url: URL, urlSessionConfiguration: URLSessionConfiguration = .default) {
        self.urlSessionConfiguration = urlSessionConfiguration
        self.request = URLRequest(url: url)
    }

    init(request: URLRequest, urlSessionConfiguration: URLSessionConfiguration = .default) {
        self.urlSessionConfiguration = urlSessionConfiguration
        self.request = request
    }

    func start(progressCallback: ProgressCallback? = nil) async throws -> URL {
        self.progressCallback = progressCallback

        return try await withCheckedThrowingContinuation { continuation in
            self.startDate = Date()
            self.downloadContinuation = continuation

            self.task.resume()
        }
    }
}

extension DownloadOperation: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error {
            self.downloadContinuation.resume(throwing: error)
        }
    }
}

extension DownloadOperation: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            self.downloadContinuation.resume(throwing: error)
        }
    }
}

extension DownloadOperation: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        self.progressCallback?(downloadTask.progress(givenStartDate: self.startDate))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // It's easier to debug issues if the file name is recognizable, but in unlikely circumstances where
            // the filename *isn't* available, we'll use a UUID
            let filename = self.request.url?.lastPathComponent ?? UUID().uuidString

            // It's possible for the download to fail after this method completes, but before our temp destination file
            // is moved to its final location. In this case, a retry would cause an error unless the temp destination
            // has a unique name – to handle that case, we'll append a unique suffix to the filenam
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                .appendingPathExtension(String(UUID().uuidString.prefix(6)))
                .appendingPathExtension("tmp")

            try FileManager.default.moveItem(at: location, to: destination)
            self.downloadContinuation.resume(returning: destination)
        } catch {
            self.downloadContinuation.resume(throwing: error)
        }
    }
}

extension URLSessionDownloadTask {
    func progress(givenStartDate startDate: Date) -> Progress {
        let now = Date()
        let elapsedTime = now.timeIntervalSince(startDate)

        let progress = Progress(totalUnitCount: self.countOfBytesExpectedToReceive)
        progress.completedUnitCount = self.countOfBytesReceived
        progress.kind = .file
        progress.setUserInfoObject(Progress.FileOperationKind.downloading.rawValue, forKey: .fileOperationKindKey)
        progress.estimateThroughput(fromTimeElapsed: elapsedTime)

        return progress
    }
}
