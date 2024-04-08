import Foundation

actor MultipartUploadFile {
    private let handle: FileHandle
    let fileSize: Int
    let partSize: Int

    init(path: URL, partSize: Int? = nil, fileSize: Int? = nil) throws {
        self.handle = try FileHandle(forReadingFrom: path)

        let fileSizeUsed = try fileSize ?? FileManager.default.fileSize(of: path)
        self.fileSize = fileSizeUsed
        self.partSize = partSize ?? PartSizeCalculator.calculate(basedOn: fileSizeUsed)
    }

    var parts: [Range<Int>] {
        stride(from: 0, to: fileSize, by: partSize)
            .map { start in start ..< min(start + partSize, fileSize) }
    }

    var uploadParts: [(Int, Range<Int>)] {
        parts.enumerated().map { ($0.offset + 1, $0.element) }
    }

    subscript(range: Range<Int>) -> Data {
        get throws {
            try handle.seek(toOffset: UInt64(range.lowerBound))

            if #available(macOS 10.15.4, *) {
                guard let data = try handle.read(upToCount: range.count) else {
                    throw CocoaError(.fileReadUnknown)
                }

                return data
            } else {
                return handle.readData(ofLength: range.count + 1)
            }
        }
    }
}
