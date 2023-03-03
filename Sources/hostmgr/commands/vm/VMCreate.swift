import Foundation
import Virtualization
import ArgumentParser
import Cocoa
import libhostmgr

struct VMCreateCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new VM"
    )

    @Argument
    var name: String

    @Option(help: "The disk size of machine that should be created, in GB")
    var diskSize: Int = 64

    private var continuation: CheckedContinuation<Void, Error>!

    private enum CodingKeys: String, CodingKey {
        case name
        case diskSize
    }

    mutating func run() async throws {
        let restoreImage = try await VZMacOSRestoreImage.latestSupported

        if VMDownloader.needsToDownload(restoreImage: restoreImage) {
            let downloadProgressBar = Console.startProgress("Downloading")
            try await VMDownloader.download(restoreImage: restoreImage, progress: downloadProgressBar.update)
            Console.success("Downloaded Restore Image")
        }

        let localImage = try await VMDownloader.localCopy(of: restoreImage)

        let bundle = try VMBundle.createBundle(
            named: self.name,
            fromRestoreImage: localImage,
            withStorageCapacity: .init(value: Double(diskSize), unit: .gigabytes)
        )

        let progressBar = Console.startProgress("Installing")

        let installer = try await VMInstaller(forBundle: bundle, restoreImage: localImage)
        try await installer.install(progressCallback: progressBar.update)

        Console.success("Installation Complete – you can now start the VM")
    }
}
