import Foundation
import ArgumentParser
import Tqdm
import libhostmgr

struct VMRemoteImageDownload: AsyncParsableCommand {

    struct Constants {
        static let imageName = "$IMAGENAME"
    }

    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download a given image and set it up for use"
    )

    @Argument(
        help: "The name of the image you would like to download"
    )
    var name: String

    @Option(
        name: .shortAndLong,
        help: "The path the image should be downloaded to"
    )
    var destination: String = Configuration.shared
        .vmStorageDirectory
        .appendingPathComponent(Constants.imageName)
        .path

    func run() async throws {
        let remote = RemoteVMRepository()

        guard let remoteImage = try await remote.getImage(named: self.name) else {
            logger.error("Unable to find remote image named \(self.name)")
            throw ExitCode(rawValue: 1)
        }

        let newDestination = destination.replacingOccurrences(
            of: Constants.imageName,
            with: remoteImage.fileName
        )

        let destination = URL(fileURLWithPath: newDestination)

        logger.info("Downloading \(name) to \(destination)")

        let sleepManager = SystemSleepManager(reason: "Downloading \(remoteImage.fileName)")
        sleepManager.disable()

        let progressBar = Tqdm(
            description: "Downloading \(remoteImage.fileName)",
            total: Int(remoteImage.imageObject.size),
            unit: " bytes",
            unitScale: true
        )

        try await remote.download(image: remoteImage, to: destination) {
            progressBar.update(n: $0.percent)
        }

        progressBar.close()
    }
}
