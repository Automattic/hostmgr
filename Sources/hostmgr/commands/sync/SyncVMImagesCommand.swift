import Foundation
import ArgumentParser
import libhostmgr

struct SyncVMImagesCommand: AsyncParsableCommand, FollowsCommandPolicies {

    static let configuration = CommandConfiguration(
        commandName: Configuration.SchedulableSyncCommand.vmImages.rawValue,
        abstract: "Sync this machine's VM images with those available remotely"
    )

    @OptionGroup
    var options: SharedSyncOptions

    static let commandIdentifier: String = "sync-vm-images"

    /// A set of command policies that control the circumstances under which this command can be run
    static let commandPolicies: [CommandPolicy] = [
        .serialExecution,
        .scheduled(every: 3600)
    ]

    func run() async throws {
        try to(evaluateCommandPolicies(), unless: options.force)
        Console.heading("Syncing VM Images")

        // Clean up no-longer-needed local images
        let deleteList = try await libhostmgr.listLocalImagesToDelete()
        try libhostmgr.deleteLocalImages(list: deleteList)

        // Download and install any remote images that we don't have yet
        let downloadList = try await libhostmgr.listAvailableRemoteImages()
        for image in downloadList {
            try await libhostmgr.fetchRemoteImage(name: image.basename)
        }

        try recordLastRun()
    }
}
