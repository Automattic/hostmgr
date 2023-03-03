import Foundation
import Virtualization

@available(macOS 11.0, *)
public struct VMDownloader {

    public typealias ProgressCallback = (Progress) -> Void

    public static func fetchLatestRestoreImage() async throws -> VZMacOSRestoreImage {
        Console.info("Fetching latest restore image")
        return try await withCheckedThrowingContinuation {
            VZMacOSRestoreImage.fetchLatestSupported(completionHandler: $0.resume)
        }
    }

    public static func needsToDownload(restoreImage: VZMacOSRestoreImage) -> Bool {
        let destination = Paths.applicationCacheDirectory.appendingPathComponent(restoreImage.url.lastPathComponent)
        return !FileManager.default.fileExists(at: destination)
    }

    public static func download(restoreImage: VZMacOSRestoreImage, progress: @escaping ProgressCallback) async throws {
        let destination = Paths.applicationCacheDirectory.appendingPathComponent(restoreImage.url.lastPathComponent)

        try FileManager.default.createDirectory(at: Paths.applicationCacheDirectory, withIntermediateDirectories: true)

        // Don't redownload the restore image if we already have it
        guard !FileManager.default.fileExists(at: destination) else {
            return
        }

        Console.info("Downloading latest restore image from \(restoreImage.url)")
        try await download(url: restoreImage.url, to: destination, progress: progress)
    }

    public static func localCopy(of restoreImage: VZMacOSRestoreImage) async throws -> VZMacOSRestoreImage {
        let destination = Paths.applicationCacheDirectory.appendingPathComponent(restoreImage.url.lastPathComponent)
        return try await VZMacOSRestoreImage.image(from: destination)
    }

    private static func download(url: URL, to destination: URL, progress: @escaping ProgressCallback) async throws {
        try await withCheckedThrowingContinuation {
            let delegate = DownloadDelegate(destination: destination, continuation: $0, progressCallback: progress)
            let task = URLSession.shared.downloadTask(with: URLRequest(url: url))
            task.delegate = delegate
            task.resume()
        }
    }
}

@available(macOS 11.0, *)
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {

    private let destination: URL
    private let continuation: CheckedContinuation<Void, Error>
    private let progressCallback: VMDownloader.ProgressCallback?

    init(
        destination: URL,
        continuation: CheckedContinuation<Void, Error>,
        progressCallback: VMDownloader.ProgressCallback? = nil
    ) {
        self.destination = destination
        self.continuation = continuation
        self.progressCallback = progressCallback

        super.init()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            try FileManager.default.moveItem(at: location, to: self.destination)
            self.continuation.resume()
        } catch {
            self.continuation.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else {
            return
        }

        self.continuation.resume(throwing: error)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progress.completedUnitCount = totalBytesWritten

        self.progressCallback?(progress)
    }
}
