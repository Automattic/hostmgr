import Foundation

public protocol VMProvider {

    associatedtype VM: RemoteVMImage

    /// Calculates a list of images that don't exist on the local machine and should be downloaded (according to the remote manifest)
    func listAvailableRemoteImages(sortedBy: RemoteVMImageSortingStrategy) async throws -> [VM]

    /// Make a remote image available for use
    ///
    /// This method is the preferred way to install a remote image on a VM Host.
    func fetchRemoteImage(name: String) async throws
}
