import Foundation

/// Downloads and registers an image by name
///
/// This method is the preferred way to install a remote image on a VM Host.
public func fetchRemoteImage(name: String) async throws {
    if try LocalVMRepository().lookupVM(withName: name) == nil {
        try await downloadRemoteImage(name: name)
    }

    guard let localVM = try LocalVMRepository().lookupVM(withName: name, state: [.ready, .compressed]) else {
        Console.error("Unable to find local VM: `\(name)`")
        abort()
    }

    try await unpack(localVM: localVM)

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
        Console.crash(
            message: "Unable to find an image named `\(name)` for \(ProcessInfo.processInfo.processorArchitecture)",
            reason: .unableToFindRemoteImage
        )
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
public func unpack(localVM: LocalVMImage) async throws {

    #if arch(arm64)
    guard localVM.state == .compressed else {
        return
    }

    Console.info("Unpacking VM")
    let destination = Paths.toVMTemplate(named: localVM.basename)
    try Compressor().decompress(archiveAt: localVM.path, to: destination)
    try FileManager.default.removeItem(at: localVM.path)
    Console.success("Extraction Complete")

    Console.info("Validating VM")
    try VMTemplate(at: destination).validate()
    Console.success("Validation Complete")

    #else
    try await ParallelsVMRepository().unpack(localVM: localVM)
    #endif
}

/// Resets local VM storage by removing all registered Parallels VMs and temporary VM clones.
///
public func resetVMStorage() throws {
    try FileManager.default.removeItem(at: Paths.ephemeralVMStorageDirectory)

    if ProcessInfo.processInfo.isIntelArchitecture {
        try ParallelsVMRepository().lookupVMs().forEach { parallelsVM in
            Console.info("Removing Registered VM \(parallelsVM.name)")
            try parallelsVM.unregister()
        }
    }

    try FileManager.default.createDirectory(at: Paths.ephemeralVMStorageDirectory, withIntermediateDirectories: true)

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
public func startVM(withLaunchConfiguration config: LaunchConfiguration) async throws {
    #if arch(arm64)
    try await XPCService.startVM(withLaunchConfiguration: config)
    Console.success("VM is starting up")
    #else
    try await ParallelsVMRepository().startVM(named: config.name)
    #endif
}

public func stopAllRunningVMs(immediately: Bool = true) async throws {
    #if arch(arm64)
    try await XPCService.stopVM()
    #else
    try await ParallelsVMRepository().stopAllRunningVMs(immediately: immediately)
    #endif

    Console.success("Shutdown Complete")
}

public func stopRunningVM(name: String, immediately: Bool) async throws {
    #if arch(arm64)
    try await XPCService.stopVM()
    #else
    try await ParallelsVMRepository().stopRunningVM(named: name, immediately: immediately)
    #endif

    Console.success("Shutdown Complete")
}
