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

    @Flag(help: "Suppress most output – similar for use from other CLI tools")
    var quiet: Bool = false

    @Option(help: "The disk size of machine that should be created, in GB")
    var diskSize: Int = 92

    private enum CodingKeys: String, CodingKey {
        case name
        case diskSize
        case quiet
    }

    mutating func run() async throws {
        let restoreImage = try await VZMacOSRestoreImage.latestSupported

        if VMDownloader.needsToDownload(restoreImage: restoreImage) {
            try await download(restoreImage: restoreImage, withProgress: !quiet)
        }

        let localImage = try await VMDownloader.localCopy(of: restoreImage)

        let bundle = try VMBundle.createBundle(
            named: self.name,
            fromRestoreImage: localImage,
            withStorageCapacity: .init(value: Double(diskSize), unit: .gigabytes)
        )

        try await install(restoreImage: localImage, into: bundle, withProgress: !quiet)

        Console.info("You now start the VM by running `hostmgr vm start \(name)`")
    }

    private func download(restoreImage: VZMacOSRestoreImage, withProgress: Bool) async throws {
        if withProgress {
            let downloadProgressBar = Console.startFileDownload(restoreImage.url)
            try await VMDownloader.download(restoreImage: restoreImage, progress: {
                downloadProgressBar.update($0)
            })
            downloadProgressBar.succeed()
        } else {
            Console.info("Downloading \(restoreImage.url) – this may take a while")
            try await VMDownloader.download(restoreImage: restoreImage) { _ in }
        }
    }

    private func install(restoreImage: VZMacOSRestoreImage, into bundle: VMBundle, withProgress: Bool) async throws {
        if withProgress {
            let tmp = Console.startIndeterminateProgress("Preparing Installer")
            var progressBar: libhostmgr.ProgressBar?

            let installer = try await VMInstaller(forBundle: bundle, restoreImage: restoreImage)
            try await installer.install { progress in
                if let progressBar {
                    progressBar.update(progress)
                } else {
                    tmp.succeed()
                    progressBar = Console.startProgress("Installing macOS:", type: .installation)
                }
            }
            progressBar?.succeed()
        } else {
            Console.info("Installing macOS – this may take a while")
            let installer = try await VMInstaller(forBundle: bundle, restoreImage: restoreImage)
            try await installer.install { _ in }
        }
    }
}
