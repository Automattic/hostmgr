import Foundation
import Virtualization
import ArgumentParser
import Cocoa
import libhostmgr

#if arch(arm64)
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
            let downloadProgressBar = Console.startFileDownload(restoreImage.url)
            try await VMDownloader.download(restoreImage: restoreImage, progress: {
                downloadProgressBar.update($0)
            })
            downloadProgressBar.succeed()
        }

        let localImage = try await VMDownloader.localCopy(of: restoreImage)

        let bundle = try VMBundle.createBundle(
            named: self.name,
            fromRestoreImage: localImage,
            withStorageCapacity: .init(value: Double(diskSize), unit: .gigabytes)
        )

        let tmp = Console.startIndeterminateProgress("Preparing Installer")
        var progressBar: libhostmgr.ProgressBar?

        let installer = try await VMInstaller(forBundle: bundle, restoreImage: localImage)
        try await installer.install { progress in
            if let progressBar {
                progressBar.update(progress)
            } else {
                tmp.succeed()
                progressBar = Console.startProgress("Installing macOS:", type: .installation)
            }
        }
        progressBar?.succeed()

        Console.info("You now start the VM by running `hostmgr vm start \(name)`")
    }
}
#endif
