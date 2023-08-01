import Foundation

public enum ExitCode: Int32, Error {
    case fileNotFound
    case unableToFindRemoteImage
    case unableToImportVM
    case invalidVMStatus
    case notEnoughLocalDiskSpace
    case parallelsVirtualMachineDoesNotExist
    case parallelsVirtualMachineIsNotStopped
    case parallelsVirtualMachineAlreadyExists
    case missingArgument
    case deprecated
}
