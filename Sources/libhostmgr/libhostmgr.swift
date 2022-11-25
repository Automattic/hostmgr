import Foundation
import prlctl

private let parallels = Parallels()

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
public func downloadRemoteImage(name: String) async throws -> URL {
    guard let remoteImage = try await RemoteVMRepository.shared.getImage(named: name) else {
        Console.crash(message: "Unable to find remote image: \(name)", reason: .unableToFindRemoteImage)
    }

    return try await downloadRemoteImage(remoteImage)
}

/// Downloads the given remote VM image to the given directory
///
/// Does not import or register the images – this method only handles download.
@discardableResult
public func downloadRemoteImage(
    _ remoteImage: RemoteVMImage,
    storageDirectory: URL = Configuration.shared.vmStorageDirectory
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

    let destination = try await RemoteVMRepository.shared.download(
        image: remoteImage,
        progressCallback: progressBar.update
    )

    Console.success("Download Complete")

    return destination
}

/// Convert a Parallels `pvmp` VM image package into a VM that's ready for use
///
public func unpackVM(name: String) async throws {

    guard let localVM = try await LocalVMRepository().lookupVM(withName: name) else {
        Console.crash(message: "Local VM \(name) could not be found", reason: .fileNotFound)
    }

    guard let importedVirtualMachine = try await parallels.importVM(at: localVM.path) else {
        Console.crash(message: "Unable to import VM at: \(localVM.path)", reason: .unableToImportVM)
    }

    guard localVM.state == .packaged, let package = importedVirtualMachine.asPackagedVM() else {
        Console.crash(message: "VM \(name) is not a packaged VM", reason: .invalidVMStatus)
    }

    Console.info("Unpacking \(package.name) – this will take a few minutes")
    do {
        try await parallels.unpackVM(withHandle: name)

        guard let unpackedVM = try await parallels.lookupVM(named: package.uuid) else {
            Console.crash(message: "Unable to find VM named: \(name)", reason: .unableToImportVM)
        }

        // If we simply rename the `.pvmp` file, the underlying `pvm` file may retain its original name. We should
        // update the file on disk to reference this name
        if name != unpackedVM.name {
            Console.info("Fixing Parallels VM Label")
            try await parallels.renameVM(withHandle: unpackedVM.uuid, to: name)
            Console.success("Parallels VM Label Fixed")
        }

        Console.success("Finished Unpacking VM")
    } catch {
        Console.error("Error unpacking VM – deleting local file")

        try FileManager.default.removeItem(at: localVM.path)
        throw error
    }
    Console.success("Unpacked \(package.name)")

    Console.info("Cleaning Up")
    try await parallels.unregisterVM(named: name)
    Console.success("Done")
}

/// Resets local VM storage by removing all registered Parallels VMs and temporary VM clones.
///
public func resetVMStorage() async throws {
    let repository = LocalVMRepository()
    for localVM in try await repository.list() {
        Console.info("Removing temp VM file for \(localVM.filename)")
        try await repository.delete(image: localVM)
    }

    for parallelsVM in try await parallels.lookupAllVMs() {
        Console.info("Removing Registered VM \(parallelsVM.name)")
        try await parallels.unregisterVM(named: parallelsVM.uuid)
    }

    Console.success("Cleanup Complete")
}

/// Deletes local VM image files from the disk
///
public func deleteLocalImages(
    list: [LocalVMImage],
    localRepository: LocalVMRepository = LocalVMRepository.shared
) async throws {

    // Don't print anything to the log if there are no images to download
    guard !list.isEmpty else {
        return
    }

    Console.printList(list.map(\.filename), title: "Deleting \(list.count) local images:")

    for image in list {
        Console.warn("Deleting \(image.filename)")
        try await localRepository.delete(image: image)
        Console.success("Done")
    }

    Console.success("Deletion Complete")
}

/// Calculates a list of images that don't exist on the local machine and should
/// be downloaded (according to the remote manifest)
public func listAvailableRemoteImages(
    sortedBy strategy: RemoteVMRepository.RemoteVMImageSortingStrategy = .newest,
    localRepository: LocalVMRepository = LocalVMRepository.shared
) async throws -> [RemoteVMImage] {
    let manifest = try await RemoteVMRepository.shared.getManifest()
    let remoteImages = try await RemoteVMRepository.shared.listImages(sortedBy: strategy)
    let localImages = try await localRepository.list()

    return remoteImages
        .filter(includingItemsIn: manifest)
        .filter(excludingItemsIn: localImages.map(\.basename))
}

/// Calculates a list of local images that should be deleted because they're not part of the remote manifest
///
public func listLocalImagesToDelete(
    localRepository: LocalVMRepository = LocalVMRepository.shared
) async throws -> [LocalVMImage] {
    let manifest = try await RemoteVMRepository.shared.getManifest()
    let localImages = try await localRepository.list()

    return localImages
        .filter(excludingItemsIn: manifest)
        .filter(excludingItemsIn: Configuration.shared.protectedImages)
}

// MARK: Virtual Machine Control
public func lookupParallelsVMOrExit(withIdentifier id: String) async throws -> VM {
    guard let parallelsVirtualMachine = try await parallels.lookupVM(named: id) else {
        Console.crash(
            message: "There is no VM with the name or UUID `\(id)` registered with Parallels",
            reason: .parallelsVirtualMachineDoesNotExist
        )
    }

    return parallelsVirtualMachine
}

public func startVM(name: String) async throws {
    let startDate = Date()

    guard let sourceVM = try await LocalVMRepository().lookupVM(withName: name) else {
        Console.crash(message: "VM \(name) could not be found", reason: .fileNotFound)
    }

    try await resetVMStorage()

    if sourceVM.state == .packaged {
        try await unpackVM(name: name)
        return try await startVM(name: name)
    }

    let destination = FileManager.default.temporaryFilePath(named: name + ".tmp.pvm")
    try FileManager.default.removeItemIfExists(at: destination)
    try FileManager.default.copyItem(at: sourceVM.path, to: destination)
    Console.info("Created temporary VM at \(destination)")

    guard let parallelsVM = try await parallels.importVM(at: destination)?.asStoppedVM() else {
        Console.crash(message: "Unable to import VM: \(destination)", reason: .unableToImportVM)
    }

    Console.success("Successfully Imported \(parallelsVM.name) with UUID \(parallelsVM.uuid)")

    try await applyVMSettings([
        .memorySize(Int(ProcessInfo().physicalMemory / 1024 / 1024) - 4096),  // We should make this configurable
        .cpuCount(ProcessInfo().physicalProcessorCount),
        .hypervisorType(.apple),
        .networkType(.shared),
        .isolateVM(.on),
        .sharedCamera(.off)
    ], to: parallelsVM)

    try await parallels.startVM(withHandle: name, wait: true)
    try await waitForVMStartup(parallelsVM)

    let elapsed = Date().timeIntervalSince(startDate)
    Console.success("Booted \(parallelsVM.name) \(Format.time(elapsed))")
}

public func stopAllRunningVMs(immediately: Bool = true) async throws {
    for parallelsVM in try await parallels.lookupRunningVMs() {
        try await parallels.shutdownVM(withHandle: parallelsVM.uuid, immediately: immediately)
    }
}

public func stopRunningVM(name: String, immediately: Bool) async throws {
    let parallelsVM = try await lookupParallelsVMOrExit(withIdentifier: name)

    guard let vmToStop = parallelsVM.asRunningVM() else {
        Console.exit(
            message: "\(parallelsVM.name) is not running, so it can't be stopped",
            style: .warning
        )
    }

    Console.info("Shutting down \(parallelsVM.name)")

    try await parallels.shutdownVM(withHandle: vmToStop.name, immediately: immediately)
    try await parallels.unregisterVM(named: parallelsVM.name)

    // Clean up after ourselves by deleting the VM files
    let vmPath = FileManager.default.temporaryDirectory.appendingPathComponent(parallelsVM.name + ".tmp.pvm")

    guard FileManager.default.directoryExists(at: vmPath) else {
        Console.success("Shutdown Complete")
        return
    }

    Console.info("Deleting VM storage from \(vmPath)")
    try FileManager.default.removeItem(at: vmPath)

    Console.success("Shutdown Complete")
}

func waitForVMStartup(_ parallelsVirtualMachine: StoppedVM) async throws {
    repeat {
        usleep(100)
    } while try await parallels.lookupRunningVMs()
        .filter { $0.uuid == parallelsVirtualMachine.uuid && $0.hasIpV4Address }
        .isEmpty
}

func applyVMSettings(_ settings: [VMOption], to parallelsVM: StoppedVM) async throws {
    Console.info("Applying VM Settings")

    // Always leave 4GB available to the VM host – the VM can have the rest
    let dedicatedMemoryForVM = ProcessInfo().physicalMemory - (4096 * 1024 * 1024) // We should make this configurable
    let cpuCoreCount = ProcessInfo().physicalProcessorCount

    Console.printTable(data: [
        ["Total System Memory", Format.memoryBytes(ProcessInfo().physicalMemory)],
        ["VM System Memory", Format.memoryBytes(dedicatedMemoryForVM)],
        ["VM CPU Cores", "\(cpuCoreCount)"],
        ["Hypervisor Type", "apple"],
        ["Networking Type", "bridged"]
    ])

    for setting in settings {
        try await parallels.setVMOption(setting, onVirtualMachineWithHandle: parallelsVM.uuid)
    }

    // These are optional, and it's possible they've already been removed, so they may fail
    do {
        try await parallels.setVMOption(.withoutSoundDevice(), onVirtualMachineWithHandle: parallelsVM.uuid)
        try await parallels.setVMOption(.withoutCDROMDevice(), onVirtualMachineWithHandle: parallelsVM.uuid)
    } catch {
        Console.warn("Unable to remove device: \(error.localizedDescription)")
    }
}
