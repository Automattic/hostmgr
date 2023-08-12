import Foundation
import System
import Compression
import AppleArchive

public struct Compressor {

    enum Errors: Error {
        case fileExistsAtPath
<<<<<<< HEAD
=======
        case unableToCompress
        case unableToDecompress
>>>>>>> b9c7883 (Add cache commands)
    }

    // From Apple Sample Code: https://developer.apple.com/documentation/accelerate/compressing_file_system_directories
    private static let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")!

<<<<<<< HEAD
    public static func compress(directory: URL, to destination: URL? = nil) throws {
=======
    @discardableResult
    public static func compress(directory: URL, to destination: URL? = nil) throws -> URL {
>>>>>>> b9c7883 (Add cache commands)

        let destination = destination ?? FileManager.default.temporaryDirectory.appendingPathComponent("archive.aar")

        guard
            let archiveFilePath = FilePath(destination),
            let writeFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .writeOnly,
                options: [ .create ],
                permissions: FilePermissions(rawValue: 0o644)
            ),
            let compressionStream = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: writeFileStream),
            let encodeStream = ArchiveStream.encodeStream(writingTo: compressionStream)
        else {
<<<<<<< HEAD
            return
        }

        try encodeStream.writeDirectoryContents(archiveFrom: FilePath(directory.path), keySet: keySet)
    }

    func decompress(archiveAt archivePath: URL, to destination: URL) throws {
=======
            throw Errors.unableToCompress
        }

        try encodeStream.writeDirectoryContents(archiveFrom: FilePath(directory.path), keySet: keySet)
        return destination
    }

    @discardableResult
    public static func decompress(archiveAt archivePath: URL, to destination: URL) throws -> URL{
>>>>>>> b9c7883 (Add cache commands)

        guard !FileManager.default.fileExists(at: destination) else {
            throw Errors.fileExistsAtPath
        }

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        guard
            let archiveFilePath = FilePath(archivePath),
            let readFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .readOnly,
                options: [ ],
                permissions: FilePermissions(rawValue: 0o644)
            ),
            let decompressionStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream),
            let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressionStream),
            let decompressDestination = FilePath(destination),
            let extractStream = ArchiveStream.extractStream(
                extractingTo: decompressDestination,
                flags: [ .ignoreOperationNotPermitted ]
            )

        else {
<<<<<<< HEAD
            return
        }

        _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
=======
            throw Errors.unableToDecompress
        }

        _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)

        return destination
>>>>>>> b9c7883 (Add cache commands)
    }
}
