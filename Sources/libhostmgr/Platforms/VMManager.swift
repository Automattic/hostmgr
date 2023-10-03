import Foundation
import Network

/// A protocol implementing a control layer for Virtual Machines – anything that you could do from a GUI, you should
/// be able to do with this protocol.
public protocol VMManager {

    associatedtype VM: LocalVMImage

    /// Start a VM
    ///
    func startVM(configuration: LaunchConfiguration) async throws

    /// Immediately terminate a VM
    /// 
    func stopVM(name: String) async throws

    /// Immediately terminates all running VMs
    func stopAllRunningVMs() async throws

    /// Delete a local VM
    ///
    func removeVM(name: String) async throws

    /// Unpack a packaged VM
    ///
    /// This method expects that the packaged VM is located in the `vm-images` directory – referencing it by name will attempt to unpack the
    /// VM at that location. If there is no packaged VM at that location, this method will emit an error.
    func unpackVM(name: String) async throws

    /// Package a VM for use on other machines
    ///
    /// This method expects that the VM to be packaged is located in the `vm-images` directory – referencing it by name will attempt to pack
    /// the VM in the directory with that name. If there is no VM at that location, an error will be emitted.
    func packageVM(name: String) async throws

    /// Resets the VM working directory by deleting any VMs that might have previously existed.
    ///
    /// This helps the node to be resilient against errors in the VM – if there's some consistent failure that prevents cleanup, we
    /// can ensure that the disk won't fill up.
    func resetVMWorkingDirectory() async throws

    /// Copy a VM template to a temporary location, making the VM ready for use
    ///
    /// - Parameters:
    ///   - from: The name of the VM template to copy. The VM template is expected to be located in the `vm-images` directory. If there is no VM at that location, an error will be emitted.
    ///   - to: The name of the resulting VM
    func cloneVM(from: String, to: String) async throws

    /// Wait for the VM with the given name to finish starting up
    ///
    func waitForVMStartup(name: String) async throws

    /// Get details about a VM
    func ipAddress(forVmWithName: String) async throws -> IPv4Address

    /// Free up disk space by removing unused images
    func purgeUnusedImages() async throws

    /// Find the template for a given VM name
    func vmTemplateName(forVmWithName: String) async throws -> String?
}

extension VMManager {

    public func list(sortedBy strategy: LocalVMImageSortingStrategy = .name) async throws -> [any LocalVMImage] {
        try (lookupVMImages() + lookupTempVMs()).sorted(by: strategy.sortMethod)
    }

    public func hasLocalVM(name: String, state: VMImageState) async throws -> Bool {
        try lookupVMImages().contains { $0.name == name && $0.state == state }
    }

    public func hasTempVM(named name: String) async throws -> Bool {
        try lookupTempVMs().contains { $0.name == name }
    }

    func lookupVMImages() throws -> [VM] {
        try resolveVMs(FileManager.default.children(ofDirectory: Paths.vmImageStorageDirectory))
    }

    func lookupTempVMs() throws -> [VM] {
        try resolveVMs(FileManager.default.children(ofDirectory: Paths.vmWorkingStorageDirectory))
    }

    func lookupTempVM(name: String) throws -> VM? {
        try lookupVMImages().first { $0.name == name }
    }

    func createWorkingDirectoriesIfNeeded() throws {
        try FileManager.default.createDirectory(at: Paths.vmImageStorageDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: Paths.vmWorkingStorageDirectory, withIntermediateDirectories: true)
    }

    private func resolveVMs(_ paths: [URL]) -> [VM] {
        paths.compactMap { VM(path: $0) }
    }
}

extension VMManager {
    func ensureLocalVMExists(named name: String) async throws {
        guard try await hasLocalVM(name: name, state: .ready) else {
            throw HostmgrError.localVMNotFound(name)
        }
    }
}
