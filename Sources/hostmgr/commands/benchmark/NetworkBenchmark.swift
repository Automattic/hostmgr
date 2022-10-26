import Foundation
import ArgumentParser
import prlctl
import Logging
import libhostmgr

private let startDate = Date()

struct NetworkBenchmark: ParsableCommand {

    typealias RemoteImage = VMRemoteImageManager.RemoteImage

    static let configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Test Network Speed"
    )

    func run() throws {
        guard let file = try VMRemoteImageManager()
            .list()
            .sorted(by: self.imageSizeSort)
            .first
        else {
            throw CleanExit.message("Unable to find a remote image to use as a network benchmark")
        }

        try S3Manager().streamingDownloadFile(
            region: Configuration.shared.vmImagesRegion,
            bucket: Configuration.shared.vmImagesBucket,
            key: file.imageObject.key,
            destination: URL(fileURLWithPath: "/dev/null"),
            progressCallback: self.showProgress
        )
    }

    private func imageSizeSort(_ lhs: RemoteImage, _ rhs: RemoteImage) -> Bool {
        lhs.imageObject.size < rhs.imageObject.size
    }

    private func showProgress(availableBytes: Int, downloadedBytes: Int, totalBytes: Int64) {

        // Sample only one in 100 entries
        guard Int.random(in: 0...1000) == 0 else {
            return
        }

        let downloadedSize = ByteCountFormatter.string(fromByteCount: Int64(downloadedBytes), countStyle: .file)
        let totalSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)

        let secondsElapsed = Date().timeIntervalSince(startDate)
        let perSecond = Double(downloadedBytes) / Double(secondsElapsed)
        let rate = ByteCountFormatter.string(fromByteCount: Int64(perSecond), countStyle: .file)

        logger.info("Downloaded \(downloadedSize) of \(totalSize) [Rate: \(rate) per second]")
    }
}
