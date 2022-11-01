import Foundation

public enum ExitCode: Int32, Error {

    // Local Storage Failures
    case fileNotFound
    case notEnoughLocalDiskSpace

    // Remote Storage Failures
    case unableToFindRemoteImage

    // Parallels
    case parallelsVirtualMachineDoesNotExist
    case unableToImportVM
    case invalidVMStatus

    /// CommandPolicy Failures
    case heartbeatRecordingFailed
}

