import Foundation

public struct MultipartDownloadFile {
    let workingDirectory: URL
    let downloadId: String

    let fileSize: Int
    let chunkSize: ChunkSize

    struct DownloadPart {
        let workingDirectory: URL
        let fileBasename: String
        let number: Int
        let range: Range<Int>

        var tempFilePath: URL {
            FileManager.default.temporaryDirectory.appendingPathComponent(fileBasename + "-\(number).part")
        }

        func alreadyExists() throws -> Bool {
            guard FileManager.default.fileExists(atPath: tempFilePath.path) else {
                return false
            }

            return true
        }
    }

    public enum ChunkSize {
        case small
        case `default`
        case large
        case custom(Int)

        var hash: String {
            "\(byteCount)"
        }

        var byteCount: Int {
            switch self {
            case .small: return 4_194_304
            case .default: return 8_388_608
            case .large: return 16_777_216
            case .custom(let size): return size
            }
        }
    }

    init(object: S3Object, chunkSize: ChunkSize = .default, workingDirectory: URL) {
        self.downloadId = sha256Hash(string: object.key + chunkSize.hash)
        self.fileSize = object.size
        self.chunkSize = chunkSize
        self.workingDirectory = workingDirectory
    }

    var parts: [DownloadPart] {
        var rangeStart = 0
        var rangeEnd = -1

        var index = 1
        var parts = [DownloadPart]()

        while rangeEnd < fileSize {
            rangeStart = (parts.last?.range.upperBound ?? -1) + 1
            rangeEnd = rangeStart + chunkSize.byteCount
            let newRange = rangeStart..<rangeEnd

            parts.append(DownloadPart(
                workingDirectory: workingDirectory,
                fileBasename: downloadId,
                number: index,
                range: newRange)
            )
            index += 1
        }

        return parts
    }
}
