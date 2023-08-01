import Foundation

public typealias ProgressCallback = (Progress) -> Void

public protocol RemoteFileProvider {
    func listFiles(startingWith prefix: String) async throws -> [RemoteFile]
    func hasFile(at path: String) async throws -> Bool
}

public protocol ReadOnlyRemoteFileProvider: RemoteFileProvider {
    func downloadFile(at path: String, to destination: URL, progress: @escaping ProgressCallback) async throws
}

protocol ReadWriteRemoteFileProvider: ReadOnlyRemoteFileProvider {
    func uploadFile(at source: URL, to destination: String, progress: @escaping ProgressCallback) async throws
}

protocol BytewiseRemoteFileProvider: RemoteFileProvider {
    func fetchFileBytes(forFileAt path: String) async throws -> Data
}
