import Foundation

public protocol RemoteFileProvider {
    func listFiles(startingWith prefix: String) async throws -> [RemoteFile]
    func hasFile(at path: String) async throws -> Bool
}

public protocol ReadableRemoteFileProvider: RemoteFileProvider {
    func downloadFile(at path: String, to destination: URL, progress: @escaping ProgressCallback) async throws
}

protocol WritableRemoteFileProvider: RemoteFileProvider {
    func uploadFile(at source: URL, to destination: String, progress: @escaping ProgressCallback) async throws
}

public extension [ReadableRemoteFileProvider] {
    func first(havingFileAtPath path: String) async throws -> ReadableRemoteFileProvider? {
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
