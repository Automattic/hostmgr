import Foundation

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

extension [ReadOnlyRemoteFileProvider] {
    func first(havingFileAtPath path: String) async throws -> ReadOnlyRemoteFileProvider? {
        for server in self {
            do {
                if try await server.hasFile(at: path) {
                    return server
                }
            } catch {
                continue
            }
        }

        return nil
    }
}
