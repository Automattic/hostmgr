import Foundation
import Virtualization

public struct RestoreImageLibrary {

    public static func fetchLatestRestoreImage() async throws -> VZMacOSRestoreImage {
        Console.info("Fetching latest restore image")
        return try await withCheckedThrowingContinuation {
            VZMacOSRestoreImage.fetchLatestSupported(completionHandler: $0.resume)
        }
    }

    public static func localPath(forRemoteImageAt url: URL) -> URL {
        Paths.restoreImageDirectory.appendingPathComponent(url.lastPathComponent)
    }

    public static func needsToDownload(imageAt url: URL) -> Bool {
        !FileManager.default.fileExists(at: localPath(forRemoteImageAt: url))
    }

    public static func needsToDownload(restoreImage: VZMacOSRestoreImage) -> Bool {
        needsToDownload(imageAt: restoreImage.url)
    }

    public static func download(imageAt url: URL, progress: @escaping ProgressCallback) async throws {
        try FileManager.default.createDirectory(at: Paths.restoreImageDirectory, withIntermediateDirectories: true)

        let destination = localPath(forRemoteImageAt: url)

        // Don't redownload the restore image if we already have it
        guard !FileManager.default.fileExists(at: destination) else {
            return
        }

        let tempPath = try await DownloadOperation(url: url).start(progressCallback: progress)
        try FileManager.default.copyItem(at: tempPath, to: destination)
    }

    public static func download(restoreImage: VZMacOSRestoreImage, progress: @escaping ProgressCallback) async throws {
        try await download(imageAt: restoreImage.url, progress: progress)
    }

    public static func localCopy(ofImageAt url: URL) async throws -> VZMacOSRestoreImage {
        try await VZMacOSRestoreImage.image(from: localPath(forRemoteImageAt: url))
    }

    public static func localCopy(of restoreImage: VZMacOSRestoreImage) async throws -> VZMacOSRestoreImage {
        try await localCopy(ofImageAt: restoreImage.url)
    }
}
