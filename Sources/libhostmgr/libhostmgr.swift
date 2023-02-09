import Foundation

/// Downloads and registers an image by name
///
/// This method is the preferred way to install a remote image on a VM Host.
public func fetchRemoteImage(name: String) async throws {
    try await downloadRemoteImage(name: name)

    Console.success("VM \(name) is ready")
}

/// Downloads a remote image with the given `name` and places it in the image storage directory
///
/// Does not import or register the image – this method only handles download.
@discardableResult
public func downloadRemoteImage(
    name: String,
    remoteRepository: RemoteVMRepository? = nil
) async throws -> URL {
    let remoteRepository = try remoteRepository ?? RemoteVMRepository()

    guard let remoteImage = try await remoteRepository.getCompatibleImage(named: name) else {
        Console.crash(message: "Unable to find an image named `\(name)` for \(ProcessInfo.processInfo.processorArchitecture)", reason: .unableToFindRemoteImage)
    }

    return try await downloadRemoteImage(remoteImage)
}

/// Downloads the given remote VM image to the given directory
///
/// Does not import or register the images – this method only handles download.
@discardableResult
public func downloadRemoteImage(
    _ remoteImage: RemoteVMImage,
    remoteRepository: RemoteVMRepository? = nil,
    storageDirectory: URL = Paths.vmImageStorageDirectory
) async throws -> URL {

    // If this is the first run, the storage directory may not exist, so we'll create it just in case
    try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

    let availableStorageSpace = try FileManager.default.availableStorageSpace(
        forVolumeContainingDirectoryAt: storageDirectory
    )

    guard remoteImage.imageObject.size < availableStorageSpace else {
        Console.crash(
            message: [
                "Unable to download \(remoteImage.fileName) (\(Format.fileBytes(remoteImage.imageObject.size)))",
                "not enough local storage available (\(Format.fileBytes(availableStorageSpace)))"
            ].joined(separator: " - "),
            reason: .notEnoughLocalDiskSpace
        )
    }

    let progressBar = Console.startImageDownload(remoteImage)

    let remoteRepository = try remoteRepository ?? RemoteVMRepository()
    let destination = try await remoteRepository.download(
        image: remoteImage,
        destinationDirectory: storageDirectory,
        progressCallback: progressBar.update
    )

    Console.success("Download Complete")

    return destination
}

/// Convert a Parallels `pvmp` VM image package into a VM that's ready for use
///
public func unpackVM(name: String) async throws {

    guard let localVM = try LocalVMRepository().lookupVM(withName: name) else {
        Console.crash(message: "Local VM \(name) could not be found", reason: .fileNotFound)
    }

    #if arch(arm64)
    guard #available(macOS 13.0, *) else {
        preconditionFailure("Apple Silicon in CI should only run on macOS 13 or greater")
    }
    try Compressor().decompress(archiveAt: localVM.path, to: Paths.toAppleSiliconVM(named: name))
    #else
    try await ParallelsVMRepository().unpack(localVM: localVM)
    #endif
}

/// Resets local VM storage by removing all registered Parallels VMs and temporary VM clones.
///
public func resetVMStorage() throws {
    let repository = LocalVMRepository(imageDirectory: FileManager.default.temporaryDirectory)
    try repository.list().forEach { localVM in
        Console.info("Removing temp VM file for \(localVM.filename)")
        try repository.delete(image: localVM)
    }

    try ParallelsVMRepository().lookupVMs().forEach { parallelsVM in
        Console.info("Removing Registered VM \(parallelsVM.name)")
        try parallelsVM.unregister()
    }

    Console.success("Cleanup Complete")
}

/// Deletes local VM image files from the disk
///
public func deleteLocalImages(
    list: [LocalVMImage],
    localRepository: LocalVMRepository = LocalVMRepository()
) throws {

    // Don't print anything to the log if there are no images to download
    guard !list.isEmpty else {
        return
    }

    Console.printList(list.map(\.filename), title: "Deleting \(list.count) local images:")

    for image in list {
        Console.warn("Deleting \(image.filename)")
        try localRepository.delete(image: image)
        Console.success("Done")
    }

    Console.success("Deletion Complete")
}

/// Calculates a list of images that don't exist on the local machine and should
/// be downloaded (according to the remote manifest)
public func listAvailableRemoteImages(
    sortedBy strategy: RemoteVMRepository.RemoteVMImageSortingStrategy = .newest,
    localRepository: LocalVMRepository = LocalVMRepository(),
    remoteRepository: RemoteVMRepository? = nil
) async throws -> [RemoteVMImage] {
    let remoteRepository = try remoteRepository ?? RemoteVMRepository()
    let manifest = try await remoteRepository.getManifest()
    let remoteImages = try await remoteRepository.listCompatibleImages(sortedBy: strategy)
    let localImages = try localRepository.list()

    return remoteImages
        .filter(includingItemsIn: manifest)
        .filter(excludingItemsIn: localImages.map(\.basename))
}

/// Calculates a list of local images that should be deleted because they're not part of the remote manifest
///
public func listLocalImagesToDelete(
    localRepository: LocalVMRepository = LocalVMRepository(),
    remoteRepository: RemoteVMRepository? = nil
) async throws -> [LocalVMImage] {
    let remoteRepository = try remoteRepository ?? RemoteVMRepository()
    let manifest = try await remoteRepository.getManifest()
    let localImages = try localRepository.list()

    return localImages
        .filter(excludingItemsIn: manifest)
        .filter(excludingItemsIn: Configuration.shared.protectedImages)
}

// MARK: Virtual Machine Control
@MainActor
public func startVM(name: String) async throws {
    #if arch(arm64)
    try await XPCService.startVM(named: name)
    #else
    try await ParallelsVMRepository().startVM(named: name)
    #endif

    Console.success("VM is running")
}

public func stopAllRunningVMs(
    immediately: Bool = true,
    parallelsRepository: ParallelsVMRepositoryProtocol = ParallelsVMRepository()
) async throws {
    #if arch(arm64)
    try await XPCService.stopVM()
    #else
    ParallelsVMRepository().stopAllRunningVMs(immediately: immediately)
    #endif

    Console.success("Shutdown Complete")
}

public func stopRunningVM(
    name: String,
    immediately: Bool,
    parallelsRepository: ParallelsVMRepositoryProtocol = ParallelsVMRepository()
) async throws {
    #if arch(arm64)
    try await XPCService.stopVM()
    #else
    ParallelsVMRepository().stopRunningVM(named: name, immediately: immediately)
    #endif

    Console.success("Shutdown Complete")
}
