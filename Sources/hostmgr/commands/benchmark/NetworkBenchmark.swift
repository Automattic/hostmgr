import Foundation
import ArgumentParser
import prlctl
import Logging
import libhostmgr

private let startDate = Date()

struct NetworkBenchmark: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Test Network Speed"
    )

    private static let limiter = Limiter(policy: .throttle, operationsPerSecond: 1)

    func run() async throws {
        let remoteImages = try await RemoteVMRepository().listImages(sortedBy: .size)

        guard let file = remoteImages.last else {
            throw CleanExit.message("Unable to find a remote image to use as a network benchmark")
        }

        let manager = S3Manager(
            bucket: Configuration.shared.vmImagesBucket,
            region: Configuration.shared.vmImagesRegion
        )

        try await manager.download(
            object: file.imageObject,
            to: FileManager.default.temporaryFilePath(),
            progressCallback: self.updateProgress
        )
    }

    private func imageSizeSort(_ lhs: RemoteVMImage, _ rhs: RemoteVMImage) -> Bool {
        lhs.imageObject.size < rhs.imageObject.size
    }

    private func updateProgress(_ progress: FileTransferProgress) {
        Self.limiter.perform {
            let downloadedSize = ByteCountFormatter.string(fromByteCount: Int64(progress.current), countStyle: .file)
            let totalSize = ByteCountFormatter.string(fromByteCount: Int64(progress.total), countStyle: .file)

            let secondsElapsed = Date().timeIntervalSince(startDate)
            let perSecond = Double(progress.current) / Double(secondsElapsed)

            // Don't continue unless the rate can be represented by `Int64`
            guard perSecond.isNormal else {
                return
            }

            let rate = ByteCountFormatter.string(fromByteCount: Int64(perSecond), countStyle: .file)
            logger.info("Downloaded \(downloadedSize) of \(totalSize) [Rate: \(rate) per second]")
        }
    }
}
