import Foundation

public struct StreamingFileReader {

    private let fileHandle: FileHandle
    private let bufferSize: Int

    public init(url: URL, bufferSize: Int = 16384) throws {
        self.fileHandle = try FileHandle(forReadingFrom: url)
        self.bufferSize = bufferSize
    }

    public func stream() -> Data? {
        let chunk = self.fileHandle.readData(ofLength: self.bufferSize)

        if chunk.isEmpty {
            return nil
        }

        return chunk
    }
}
