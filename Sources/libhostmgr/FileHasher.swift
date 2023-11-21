import Foundation
import CryptoKit

public struct FileHasher {

    static let bufferSize = 1_024_000

    public static func hash(fileAt url: URL) throws -> Data {
        var hasher = SHA256()

        guard
            FileManager.default.fileExists(at: url),
            let stream = InputStream(url: url)
        else {
            throw CocoaError(.fileNoSuchFile)
        }

        var buffer = [UInt8](repeating: 0, count: bufferSize)
        stream.open()
        while case let byteCount = stream.read(&buffer, maxLength: bufferSize), byteCount > 0 {
            hasher.update(data: buffer[0..<byteCount])
        }

        return Data(hasher.finalize())
    }
}
