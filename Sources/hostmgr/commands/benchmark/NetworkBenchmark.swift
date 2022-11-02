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

        let progressBar = Console.startFileDownload(file.imageObject)

        try await manager.download(
            object: file.imageObject,
            to: FileManager.default.temporaryFilePath(),
            progressCallback: progressBar.update
        )
    }

    private func imageSizeSort(_ lhs: RemoteVMImage, _ rhs: RemoteVMImage) -> Bool {
        lhs.imageObject.size < rhs.imageObject.size
    }
}
