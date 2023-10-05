import Foundation

public enum HostmgrError: Error, LocalizedError {
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
//    case parallelsVirtualMachineDoesNotExist
//    case parallelsVirtualMachineIsNotStopped
//    case parallelsVirtualMachineAlreadyExists
//    case missingArgument
//    case deprecated

    case invalidVMSourceImage(URL)

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
//        case .parallelsVirtualMachineDoesNotExist:
//
//        case .parallelsVirtualMachineIsNotStopped:
//
//        case .parallelsVirtualMachineAlreadyExists:
//
//        case .missingArgument:
//
//        case .deprecated:

        case .invalidVMSourceImage(let url):
            return  "This Mac cannot create a VM from the disk image at \(url)"

        case .helperIsMissing(let path):
            return "`hostmgr-helper` is missing – please reinstall `hostmgr` (should be at \(path))"
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
