import Foundation
import ArgumentParser
import SotoS3
import prlctl
import libhostmgr

struct SyncVMImagesCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "vm_images",
        abstract: "Sync this machine's VM images with those avaiable remotely"
    )

    func run() throws {
        try SyncVMImagesTask().run()
    }
}

struct SyncVMImagesTask {

    func run(force: Bool = false) throws {
        var state = State.get()

        guard !state.isRunning else {
            print("Already syncing VMs, so we won't try to run again")
            return
        }

        guard state.shouldRun && force else {
            print("This job is not scheduled to run until \(state.nextRunTime)")
            return
        }

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
            .filter { !manifest.contains($0) }  // If it's not in the manifest, it should be deleted
            .filter { !Configuration.shared.protectedImages.contains($0) } // If it's a protected image it should not be deleted

        logger.info("Deleting local images:\(imagesToDelete)")
        try VMLocalImageManager().delete(images: imagesToDelete)

        let storageDirectory = Configuration.shared.vmStorageDirectory

        for image in imagesToDownload {
            let destination = storageDirectory.appendingPathComponent(image.fileName)

            logger.info("Downloading the VM – this will take a few minutes")
            logger.trace("Downloading \(image.basename) to \(destination)")

            try VMRemoteImageManager().download(image: image, to: destination) { _, downloaded, total in
                /// Only update the heartbeat every 5 seconds to avoid thrashing the disk
                guard abs(state.heartBeat.timeIntervalSinceNow) > 5 else {
                    return
                }

                state.heartBeat = Date()
                try? State.set(state: state)

                let percent = String(format: "%.2f", Double(downloaded) / Double(total) * 100)
                logger.trace("\(percent)% complete")
            }

            logger.info("Download Complete")

            guard let vm = try Parallels().importVM(at: destination) else {
                print("Unable to import VM at \(destination)")
                return
            }

            guard let package = vm.asPackagedVM() else {
                throw CleanExit.message("Imported \(vm.name)")
            }

            logger.info("Unpacking the VM – this will take a few minutes")
            try package.unpack()

            logger.info("Imported Complete")
            logger.info("\tName:\t\(vm.name)")
            logger.info("\tUUID:\t\(vm.uuid)")
        }

        try State.set(state: State(lastRunAt: Date()))
    }

    struct State: Codable {
        private static let key = "sync-vm-images-state"
        var lastRunAt: Date = Date.distantPast

        var shouldRun: Bool {
            let runInterval = TimeInterval(Configuration.shared.authorizedKeysSyncInterval)
            return self.lastRunAt < Date().addingTimeInterval(runInterval * -1)
        }

        var nextRunTime: Date {
            let runInterval = TimeInterval(Configuration.shared.authorizedKeysSyncInterval)
            return self.lastRunAt.addingTimeInterval(runInterval)
        }

        var heartBeat: Date = Date.distantPast

        // if we haven't hear from a job in 60 seconds, assume it's failed and we should try again
        var isRunning: Bool {
            abs(heartBeat.timeIntervalSinceNow) < 60
        }

        static func get() -> State {
            (try? StateManager.load(key: key)) ?? State()
        }

        static func set(state: State) throws {
            try StateManager.store(key: key, value: state)
        }
    }
}
