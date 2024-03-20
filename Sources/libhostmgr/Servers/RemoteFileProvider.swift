import Foundation

public protocol RemoteFileProvider {
    func hasFile(named name: String) async throws -> Bool
}

public protocol ReadableRemoteFileProvider: RemoteFileProvider {
    func downloadFile(named name: String, to destination: URL, progress: @escaping ProgressCallback) async throws
}

protocol WritableRemoteFileProvider: RemoteFileProvider {
    func uploadFile(at source: URL, to destination: String, allowResume: Bool, progress: @escaping ProgressCallback) async throws
}

public extension [ReadableRemoteFileProvider] {
    func first(havingFileNamed name: String) async throws -> ReadableRemoteFileProvider? {
        for server in self {
            do {
                if try await server.hasFile(named: name) {
                    return server
                }
            } catch {
                continue
            }
        }

        return nil
    }
}
