import Foundation
import ArgumentParser
import SotoS3
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

    @Option(
        name: .shortAndLong,
        help: "The path to the image you would like to download"
    )
    var path: String

    @Option(
        name: .shortAndLong,
        help: "The path the image should be downloaded to"
    )
    var destination: String = Configuration.shared
        .vmStorageDirectory
        .appendingPathComponent(Constants.imageName)
        .path

    func run() async throws {
        let remote = VMRemoteImageManager()

        guard let remoteImage = try await remote.getImage(forPath: path) else {
            print("Unable to find image at path \(path)")
            Self.exit()
        }

        let newDestination = destination.replacingOccurrences(
            of: Constants.imageName,
            with: remoteImage.fileName
        )
        let destination = URL(fileURLWithPath: newDestination)

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
