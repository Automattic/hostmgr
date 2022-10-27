import Foundation
import prlctl

/// Downloads and registers an image by name
///
/// This method is the preferred way to install a remote image on a VM Host.
public func fetchRemoteImage(name: String) async throws {
    _ = try await downloadRemoteImage(name: name)
    try await importVM(name: name)

    Console.success("VM \(name) is ready")
}

/// Downloads a single remote image file and places it in the image storage directory
///
/// Does not import or register the image – this method only handles download.
@discardableResult
public func downloadRemoteImage(
    name: String,
    remoteRepository: RemoteVMRepository = RemoteVMRepository()
) async throws -> URL {
    guard let remoteImage = try await remoteRepository.getImage(named: name) else {
        Console.crash(message: "Unable to find remote image: \(name)", reason: .unableToFindRemoteImage)
    }

    return try await download(remoteImage: remoteImage)
}

/// Downloads the given remote VM image to the given directory
///
/// Does not import or register the images – this method only handles download.
@discardableResult
public func download(
    remoteImage: RemoteVMImage,
    remoteRepository: RemoteVMRepository = RemoteVMRepository(),
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
    let destination = try await remoteRepository.download(
        image: remoteImage,
        progressCallback: progressBar.update
    )

    Console.success("Download Complete")

    return destination
}

public func unpackVM(name: String) async throws {

    guard let localVM = try LocalVMRepository().lookupVM(withName: name) else {
        Console.crash(message: "VM \(name) could not be found", reason: .fileNotFound)
    }

    guard let importedVirtualMachine = try Parallels().importVM(at: localVM.path) else {
        Console.crash(message: "Unable to import VM: \(localVM.path)", reason: .unableToImportVM)
    }

    guard let package = importedVirtualMachine.asPackagedVM() else {
        Console.crash(message: "VM \(name) is not a packaged VM", reason: .invalidVMStatus)
    }

    Console.info("Unpacking \(package.name) – this will take a few minutes")
    let unpackedVM = try package.unpack()
    Console.success("Unpacked \(package.name)")

    Console.info("Cleaning up")
    try unpackedVM.unregister()
    Console.info("Done")
}

/// Prepares a local VM for use by the VM host. Automatically unpacks it first, if needed.
///
@discardableResult
public func importVM(name: String) async throws -> StoppedVM {

    guard let sourceVM = try LocalVMRepository().lookupVM(withName: name) else {
        Console.crash(message: "VM \(name) could not be found", reason: .fileNotFound)
    }

    if sourceVM.state == .packaged {
        try await unpackVM(name: name)
        return try await importVM(name: name)
    }

    let destination = FileManager.default.temporaryFilePath(named: name + ".tmp.pvm")

    try FileManager.default.copyItem(at: sourceVM.path, to: destination)
    Console.info("Created temporary VM at \(destination)")

    guard let importedVirtualMachine = try Parallels().importVM(at: destination) else {
        Console.crash(message: "Unable to import VM: \(destination)", reason: .unableToImportVM)
    }

    Console.success("Successfully Imported \(importedVirtualMachine.name) with UUID \(importedVirtualMachine.uuid)")

    guard let stoppedVM = importedVirtualMachine.asStoppedVM() else {
        Console.crash(message: "Unable to import VM: \(destination)", reason: .unableToImportVM)
    }

    return stoppedVM
}

/// Deletes local VM image files from the disk. Does not unregister them.
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

public func importLocalVMs(list: [LocalVMImage]) async throws {

    // Don't print anything to the log if there are no images to download
    guard !list.isEmpty else {
        return
    }

    Console.printList(list.map(\.filename), title: "Registering \(list.count) local images with Parallels:")

    for image in list {
        try await importVM(name: image.basename)
    }

    Console.success("Import Complete")
}

/// Calculates a list of  images that don't exist on the local machine and should
/// be downloaded (according to the remote manifest)
public func listAvailableRemoteImages(
    sortedBy strategy: RemoteVMRepository.RemoteVMImageSortingStrategy = .newest,
    localRepository: LocalVMRepository = LocalVMRepository(),
    remoteRepository: RemoteVMRepository = RemoteVMRepository()
) async throws -> [RemoteVMImage] {
    let manifest = try await remoteRepository.getManifest()
    let remoteImages = try await remoteRepository.listImages(sortedBy: strategy)
    let localImages = try localRepository.list()

    return remoteImages
        .filter(includingItemsIn: manifest)
        .filter(excludingItemsIn: localImages.map(\.basename))
}

/// Calculates a list of local images that should be deleted because they're not part of the remote manifest
///
public func listLocalImagesToDelete(
    localRepository: LocalVMRepository = LocalVMRepository(),
    remoteRepository: RemoteVMRepository = RemoteVMRepository()
) async throws -> [LocalVMImage] {
    let manifest = try await remoteRepository.getManifest()
    let localImages = try localRepository.list()

    return localImages
        .filter(excludingItemsIn: manifest)
        .filter(excludingItemsIn: Configuration.shared.protectedImages)
}

/// Calculates a list of local image files that are present on-disk, but not registered with Parallels
@available(*, deprecated)
public func listLocalImagesThatNeedToBeRegistered(
    localRepository: LocalVMRepository = LocalVMRepository()
) async throws -> [LocalVMImage] {
    let localImages = try localRepository.list()
    let registeredVMs = try Parallels().lookupAllVMs()

    return localImages.filter(excludingItemsIn: registeredVMs.map(\.name))
}

@available(*, deprecated)
public func listParallelsVMsMissingLocalImages(
    localRepository: LocalVMRepository = LocalVMRepository(),
    parallelsRepository: ParallelsVMRepository = ParallelsVMRepository()
) throws -> [VM] {
    let parallelsVMs = try parallelsRepository.lookupVMs()
    let localImages = try localRepository.list()

    return parallelsVMs.filter(excludingItemsIn: localImages.map(\.basename))
}

// MARK: Virtual Machine Control
public func lookupParallelsVMOrExit(
    withIdentifier id: String,
    parallelsRepository: ParallelsVMRepository = ParallelsVMRepository()
) throws -> VM {
    guard let parallelsVirtualMachine = try parallelsRepository.lookupVM(byIdentifier: id) else {
        Console.crash(
            message: "There is no VM with the name or UUID `\(id)` registered with Parallels",
            reason: .parallelsVirtualMachineDoesNotExist
        )
    }

    return parallelsVirtualMachine
}

public func startVM(_ parallelsVM: StoppedVM) async throws {
    let startDate = Date()

    try parallelsVM.start()

    let _: Void = try await withCheckedThrowingContinuation { continuation in
        do {
            try waitForVMStartup(parallelsVM)
        } catch {
            continuation.resume(with: .failure(error))
        }

        let elapsed = Date().timeIntervalSince(startDate)
        Console.success("Booted \(parallelsVM.name) \(Format.time(elapsed))")
        continuation.resume(with: .success(()))
    }
}

@available(*, deprecated)
public func cloneVM(
    _ parallelsVM: StoppedVM,
    cloneName: String,
    options: [StoppedVM.VMOption] = []
) async throws -> StoppedVM {
    let startDate = Date()

    if try Parallels().lookupVM(named: cloneName) != nil {
        Console.crash(
            message: "Unable to clone \(parallelsVM.name) to \(cloneName) – there's already a VM with that name",
            reason: .parallelsVirtualMachineAlreadyExists
        )
    }

    try parallelsVM.clone(as: cloneName, fast: true)

    let _: Void = try await withCheckedThrowingContinuation { continuation in
        do {
            try waitForVMToExist(withName: cloneName)
        } catch {
            continuation.resume(with: .failure(error))
        }

        let elapsed = Date().timeIntervalSince(startDate)
        Console.success("\(cloneName) cloned from \(parallelsVM.name) \(Format.time(elapsed))")
        continuation.resume(with: .success(()))
    }

    let clone = try lookupParallelsVMOrExit(withIdentifier: cloneName)

    guard let stoppedVM = clone.asStoppedVM() else {
        Console.crash(
            message: "Cloned VM `\(clone.name)` is not stopped",
            reason: .parallelsVirtualMachineIsNotStopped
        )
    }


    return stoppedVM
}

@available(*, deprecated)
public func unregisterInvalidVMs(
    parallelsRepository: ParallelsVMRepositoryProtocol = ParallelsVMRepository()
) throws {
    try unregister(parallelsRepository.lookupInvalidVMs())
}

public func stopAllRunningVMs(
    immediately: Bool = true,
    parallelsRepository: ParallelsVMRepositoryProtocol = ParallelsVMRepository()
) throws {
    for parallelsVM in try parallelsRepository.lookupRunningVMs() {
        try stopRunningVM(name: parallelsVM.name, immediately: immediately)
    }
}

public func stopRunningVM(
    name: String,
    immediately: Bool,
    parallelsRepository: ParallelsVMRepositoryProtocol = ParallelsVMRepository()
) throws {
    let parallelsVM = try lookupParallelsVMOrExit(withIdentifier: name)

    guard let vmToStop = parallelsVM.asRunningVM() else {
        Console.exit(
            message: "\(parallelsVM.name) is not running, so it can't be stopped",
            style: .warning
        )
    }

    Console.info("Shutting down \(parallelsVM.name)")

    try vmToStop.shutdown(immediately: immediately)
    try vmToStop.unregister()

    // Clean up after ourselves by deleting the VM files
    let vmPath = FileManager.default.temporaryDirectory.appendingPathComponent(parallelsVM.name + ".tmp.pvm")

    guard try FileManager.default.directoryExists(at: vmPath) else {
        Console.success("Shutdown Complete")
        return
    }

    Console.info("Deleting VM storage from \(vmPath)")
    try FileManager.default.removeItem(at: vmPath)

    Console.success("Shutdown Complete")
}

@available(*, deprecated)
public func unregister(_ list: [VMProtocol]) throws {

    // Don't print anything to the log if there are no images to download
    guard !list.isEmpty else {
        return
    }

    Console.printList(list.map(\.name), title: "Unregistering \(list.count) Parallels Virtual Machines:")

    for parallelsVM in list {
        try unregisterVM(withIdentifier: parallelsVM.uuid)
        try parallelsVM.delete()
    }
}

public func unregisterVM(withIdentifier identifier: String) throws {
    let virtualMachine = try lookupParallelsVMOrExit(withIdentifier: identifier)
    try virtualMachine.unregister()

    Console.success("Unregistered \(virtualMachine.name)")
}

func waitForVMStartup(_ parallelsVirtualMachine: StoppedVM) throws {
    repeat {
        usleep(100)
    } while try Parallels()
        .lookupRunningVMs()
        .filter { $0.uuid == parallelsVirtualMachine.uuid && $0.hasIpV4Address }
        .isEmpty
}

func waitForVMToExist(withName name: String) throws {
    repeat {
        usleep(100)
    } while try Parallels().lookupVM(named: name) == nil
}
