import Foundation
import ArgumentParser
import SotoS3
import prlctl
import libhostmgr

struct SyncVMImagesCommand: ParsableCommand, FollowsCommandPolicies {

    static let configuration = CommandConfiguration(
        commandName: "vm_images",
        abstract: "Sync this machine's VM images with those avaiable remotely"
    )

    @OptionGroup
    var options: SharedSyncOptions

    static let commandIdentifier: String = "sync-vm-images"

    /// A set of command policies that control the circumstances under which this command can be run
    static let commandPolicies: [CommandPolicy] = [
        .serialExecution,
        .scheduled(every: 3600)
    ]

    func run() throws {
        try to(evaluateCommandPolicies(), unless: options.force)

        /// The manifest defines which images should be distributed to VM hosts
        let manifest = try VMRemoteImageManager().getManifest()
        logger.debug("Downloaded manifest:\n\(manifest)")

        /// Candidate images are any that the manifest says *could* be installed on this VM host
        let candidateImages = try VMRemoteImageManager().list().filter { manifest.contains($0.basename) }
        logger.debug("Available remote images:\n\(candidateImages)")

        let localImages = try VMLocalImageManager().list()
        logger.debug("Local Images:\(localImages)")

        let imagesToDownload = candidateImages.filter { !localImages.contains($0.basename) }
        let imagesToDelete = localImages
            // If it's not in the manifest, it should be deleted
            .filter { !manifest.contains($0) }
            // If it's a protected image it should not be deleted
            .filter { !Configuration.shared.protectedImages.contains($0) }

        logger.info("Deleting local images:\(imagesToDelete)")
        try VMLocalImageManager().delete(images: imagesToDelete)

        try imagesToDownload.forEach {
            try download(image: $0)
        }

        try recordLastRun()
    }

    private func download(image: VMRemoteImageManager.RemoteImage) throws {
        let storageDirectory = Configuration.shared.vmStorageDirectory
        let destination = storageDirectory.appendingPathComponent(image.fileName)

        logger.info("Downloading the VM – this will take a few minutes")
        logger.trace("Downloading \(image.basename) to \(destination)")

        let limiter = Limiter(policy: .throttle, operationsPerSecond: 1)

        try VMRemoteImageManager().download(image: image, to: destination) { _, downloaded, total in
            limiter.perform {
                try? recordHeartbeat()
                let percent = String(format: "%.2f", Double(downloaded) / Double(total) * 100)
                logger.trace("\(percent)% complete")
            }
        }

        logger.info("Download Complete")

        guard let vmToImport = try Parallels().importVM(at: destination) else {
            print("Unable to import VM at \(destination)")
            return
        }

        guard let package = vmToImport.asPackagedVM() else {
            throw CleanExit.message("Imported \(vmToImport.name)")
        }

        logger.info("Unpacking the VM – this will take a few minutes")
        try package.unpack()

        logger.info("Imported Complete")
        logger.info("\tName:\t\(vmToImport.name)")
        logger.info("\tUUID:\t\(vmToImport.uuid)")

    }
}
