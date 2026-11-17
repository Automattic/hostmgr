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
    var diskSize: Int = 160

    @Option(help: "Path or URL of the `.ipsw` restore image to install. Defaults to the latest supported by this Mac")
    var ipsw: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case diskSize
        case quiet
        case ipsw
    }

    mutating func run() async throws {
        let localImage = try await resolveRestoreImage()

        let bundle = try VMBundle.createBundle(
            named: self.name,
            fromRestoreImage: localImage,
            withStorageCapacity: .init(value: Double(diskSize), unit: .gigabytes)
        )

        try await install(restoreImage: localImage, into: bundle, withProgress: !quiet)

        Console.info("You now start the VM by running `hostmgr vm start \(name)`")
    }

    /// Returns a local copy of the restore image to install, downloading it first if needed
    private func resolveRestoreImage() async throws -> VZMacOSRestoreImage {
        guard let ipsw else {
            let latest = try await VZMacOSRestoreImage.latestSupported
            try await downloadIfNeeded(imageAt: latest.url, withProgress: !quiet)
            return try await RestoreImageLibrary.localCopy(of: latest)
        }

        if let url = URL(string: ipsw), ["http", "https"].contains(url.scheme) {
            try await downloadIfNeeded(imageAt: url, withProgress: !quiet)
            return try await RestoreImageLibrary.localCopy(ofImageAt: url)
        }

        return try await VZMacOSRestoreImage.image(from: URL(fileURLWithPath: ipsw))
    }

    private func downloadIfNeeded(imageAt url: URL, withProgress: Bool) async throws {
        guard RestoreImageLibrary.needsToDownload(imageAt: url) else {
            return
        }

        if withProgress {
            let downloadProgressBar = Console.startFileDownload(url)
            try await RestoreImageLibrary.download(imageAt: url, progress: {
                downloadProgressBar.update($0)
            })
            downloadProgressBar.succeed()
        } else {
            Console.info("Downloading \(url) – this may take a while")
            try await RestoreImageLibrary.download(imageAt: url) { _ in }
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
