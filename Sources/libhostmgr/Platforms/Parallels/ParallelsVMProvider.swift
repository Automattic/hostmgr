import Foundation

public struct ParallelsVMProvider: VMProvider {

    @DIInjected
    private var vmManager: ParallelsVMManager

    @DIInjected
    private var remoteRepository: ParallelsVMLibrary

    public func listAvailableRemoteImages(sortedBy: RemoteVMImageSortingStrategy) async throws -> [ParallelsRemoteVMImage] {
        let manifest = try await remoteRepository.getManifest()
        return try await remoteRepository.listImages().filter(includingItemsIn: manifest)
    }

    public func fetchRemoteImage(name: String) async throws {
        Console.info("Fetching \(name)")

        guard let remoteImage = try await remoteRepository.lookupImage(named: name) else {
            Console.crash(message: "Unable to find remote image: \(name)", reason: .unableToFindRemoteImage)
        }

        // If this is the first run, the storage directory may not exist, so we'll create it just in case
        try FileManager.default.createDirectory(at: Paths.vmImageStorageDirectory, withIntermediateDirectories: true)

        let availableStorageSpace = try FileManager.default.availableStorageSpace(
            forVolumeContainingDirectoryAt: Paths.vmImageStorageDirectory
        )

        guard remoteImage.size < availableStorageSpace else {
            Console.crash(
                message: [
                    "Unable to download \(remoteImage.fileName) (\(Format.fileBytes(remoteImage.size)))",
                    "not enough local storage available (\(Format.fileBytes(availableStorageSpace)))"
                ].joined(separator: " - "),
                reason: .notEnoughLocalDiskSpace
            )
        }

        let progressBar = Console.startImageDownload(remoteImage)

        try await remoteRepository.download(
            image: remoteImage,
            destinationDirectory: Paths.vmImageStorageDirectory,
            progressCallback: progressBar.update
        )

        Console.success("Download Complete")

        try await vmManager.unpackVM(name: name)

        //    return try await downloadRemoteImage(remoteImage)

    }
}
