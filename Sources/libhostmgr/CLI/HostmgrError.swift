import Foundation

public enum HostmgrError: Error, LocalizedError, Codable {
    case missingConfigurationFile(URL)
    case localVMNotFound(String)
    case workingVMAlreadyExists(String)
    case unableToFindRemoteImage(String)
    case unableToImportVM(String)
    case invalidVMStatus(URL)
    case vmIsNotPackaged(String)
    case vmIsNotRunning(String)
    case vmHasInvalidIpAddress(String)
    case notEnoughLocalDiskSpaceToDownloadFile(String, Int, Int64)
    case helperIsMissing(URL)
    case noVMSlotsAvailable
    case vmManifestFileNotFound(URL)
    case vmManifestFileInvalid(URL)
    case vmDiskImageCorrupt(URL)
    case vmAuxDataCorrupt(URL)
    case vmConfigurationFileMissing(URL)
    case invalidVMSourceImage(URL)
    case xpcError(String)

    public var errorDescription: String? {
        switch self {
        case .missingConfigurationFile(let path):
            return "No configuration file found. Create one at \(path.path)"
        case .localVMNotFound(let name):
            return "There is no local VM named \(name)"
        case .workingVMAlreadyExists(let handle):
            return "There is already a working VM called \(handle)"
        case .unableToFindRemoteImage(let name):
            return "Unable to find remote image: \(name)"
        case .unableToImportVM(let name):
            return "Unable to import VM: \(name)"
        case .invalidVMStatus(let path):
            return "Invalid VM: \(path)"
        case .vmIsNotPackaged(let name):
            return "\(name) is not a packaged VM"
        case .vmIsNotRunning(let name):
            return "\(name) is not running"
        case .vmHasInvalidIpAddress(let name):
            return "\(name) has an invalid IP address"
        case .notEnoughLocalDiskSpaceToDownloadFile(let fileName, let requested, let available):
            return  [
                "Unable to download \(fileName) (\(Format.fileBytes(requested)))",
                "not enough local storage available (\(Format.fileBytes(available)))"
            ].joined(separator: " - ")
        case .helperIsMissing(let path):
            return "`hostmgr-helper` is missing – please reinstall `hostmgr` (should be at \(path))"
        case .noVMSlotsAvailable:
            return "Unable to launch more VMs – maximum reached"
        case .vmManifestFileNotFound(let path):
            return "VM Manifest file not found at \(path.path())"
        case .vmManifestFileInvalid(let path):
            return "The VM Manifest file at \(path.path()) cannot be read – it may be the wrong format"
        case .vmDiskImageCorrupt(let path):
            return "The VM disk image at \(path.path()) has the wrong hash – it may be corrupt. Please re-download it"
        case .vmAuxDataCorrupt(let path):
            return "The VM aux data at \(path.path()) has the wrong hash – it may be corrupt. Please re-download it"
        case .vmConfigurationFileMissing(let path):
            return "No VM configuration file found at \(path.path()). Please re-download the image"
        case .invalidVMSourceImage(let url):
            return  "This Mac cannot create a VM from the disk image at \(url)"
        case .xpcError(let string):
            return string
        }
    }

    var description: String {
        self.errorDescription ?? "foo"
    }

    var localizedDescription: String {
        self.errorDescription ?? ""
    }

    public var exitCode: Int32 {
        -1
    }
}
