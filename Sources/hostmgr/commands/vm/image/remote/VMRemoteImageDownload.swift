import Foundation
import ArgumentParser
import SotoS3
import Tqdm
import libhostmgr

struct VMRemoteImageDownload: ParsableCommand {

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

    func run() throws {
        let remote = VMRemoteImageManager()

        guard let remoteImage = try remote.getImage(forPath: path) else {
            print("Unable to find image at path \(path)")
            Self.exit()
        }

        let destination = URL(fileURLWithPath: destination.replacingOccurrences(of: Constants.imageName, with: remoteImage.fileName))

        try SystemSleepManager.disableSleepFor {
            let progress = Tqdm(description: "Downloading \(remoteImage.fileName)", total: Int(remoteImage.size), unit: " bytes", unitScale: true)
            try remote.download(image: remoteImage, to: destination) { change, downloaded, total in
                progress.update(n: change)
            }
            progress.close()
        }
    }
}
