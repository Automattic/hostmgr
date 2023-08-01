import Foundation
import Virtualization

#if arch(arm64)
public struct VMDownloader {

    public typealias ProgressCallback = (Progress) -> Void

    public static func fetchLatestRestoreImage() async throws -> VZMacOSRestoreImage {
        Console.info("Fetching latest restore image")
        return try await withCheckedThrowingContinuation {
            VZMacOSRestoreImage.fetchLatestSupported(completionHandler: $0.resume)
        }
    }

    public static func needsToDownload(restoreImage: VZMacOSRestoreImage) -> Bool {
        let destination = Paths.restoreImageDirectory.appendingPathComponent(restoreImage.url.lastPathComponent)
        return !FileManager.default.fileExists(at: destination)
    }

    public static func download(restoreImage: VZMacOSRestoreImage, progress: @escaping ProgressCallback) async throws {
        try FileManager.default.createDirectory(at: Paths.restoreImageDirectory, withIntermediateDirectories: true)

        let destination = Paths.restoreImageDirectory.appendingPathComponent(restoreImage.url.lastPathComponent)

        // Don't redownload the restore image if we already have it
        guard !FileManager.default.fileExists(at: destination) else {
            return
        }

        let tempPath = try await DownloadOperation(url: restoreImage.url).start(progressCallback: progress)
        try FileManager.default.copyItem(at: tempPath, to: destination)
    }

    public static func localCopy(of restoreImage: VZMacOSRestoreImage) async throws -> VZMacOSRestoreImage {
        let destination = Paths.restoreImageDirectory.appendingPathComponent(restoreImage.url.lastPathComponent)
        return try await VZMacOSRestoreImage.image(from: destination)
    }
}
#endif
