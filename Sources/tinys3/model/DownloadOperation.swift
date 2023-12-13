import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias ProgressCallback = (Progress) -> Void

class DownloadOperation: NSObject, RequestPerformer {

    private let request: URLRequest
    private let urlSessionConfiguration: URLSessionConfiguration
    lazy var urlSession: URLSession = URLSession(
        configuration: self.urlSessionConfiguration,
        delegate: self,
        delegateQueue: nil
    )
    private lazy var task: URLSessionDownloadTask = urlSession.downloadTask(with: self.request)

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
        self.progressCallback?(downloadTask.downloadProgress(givenStartDate: self.startDate))
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

extension URLSessionTask {
    func downloadProgress(givenStartDate startDate: Date) -> Progress {
        let progress = Progress(totalUnitCount: self.countOfBytesExpectedToReceive)
        progress.completedUnitCount = self.countOfBytesReceived
        progress.kind = .file
        progress.setUserInfoObject(Progress.FileOperationKind.downloading.rawValue, forKey: .fileOperationKindKey)
        progress.estimateThroughput(fromStartDate: startDate)

        return progress
    }
}
