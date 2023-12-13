import Foundation

actor MultipartUploadFile {
    private let handle: FileHandle
    let fileSize: Int
    let partSize: Int

    init(path: URL, partSize: Int? = nil) throws {
        self.handle = try FileHandle(forReadingFrom: path)

        let fileSize = try FileManager.default.fileSize(of: path)

        self.fileSize = fileSize
        self.partSize = PartSizeCalculator.calculate(basedOn: fileSize)
    }

    var parts: [Range<Int>] {
        var rangeStart = 0
        var rangeEnd = -1

        var parts = [Range<Int>]()

        while rangeEnd < fileSize {
            rangeStart = (parts.last?.upperBound ?? -1) + 1
            rangeEnd = rangeStart + partSize

            parts.append(rangeStart..<rangeEnd)
        }

        return parts
    }

    var uploadParts: [(Int, Range<Int>)] {
        parts.enumerated().map { ($0.offset + 1, $0.element) }
    }

    subscript(range: Range<Int>) -> Data {
        get throws {
            try handle.seek(toOffset: UInt64(range.lowerBound))

            if #available(macOS 10.15.4, *) {
                guard let data = try handle.read(upToCount: range.count + 1) else {
                    throw CocoaError(.fileReadUnknown)
                }

                return data
            } else {
                return handle.readData(ofLength: range.count + 1)
            }
        }
    }
}
