import Foundation
import ArgumentParser
import tinys3

@available(macOS 13.0, *)
@main
struct CLI: AsyncParsableCommand {

    enum Operation: String, ExpressibleByArgument {
        case upload
        case download
        case list
        case presign
        case head
    }

    enum Errors: Error {
        case unableToResolveDestination
        case invalidSource
    }

    @Argument(help: "Are we uploading a file or downloading one?")
    var operation: Operation = .download

    @Argument(help: "The file to copy")
    var source: String

    @Argument(help: "The destination for the file")
    var destination: String = "."

    mutating func run() async throws {
        switch operation {
        case .download: try await download()
        case .upload: try await upload()
        case .list: try await list()
        case .presign: try presign()
        case .head: try await head()
        }
    }

    func download() async throws {
        print("Copying \(source) to \(destination)")

        guard
            let sourceURL = URL(string: self.source),
            let bucketName = sourceURL.host
        else {
            abort()
        }

        let client = try S3Client(credentials: .fromUserConfiguration(), endpoint: .accelerated)

        let destination = try resolveDestination()

        let tempDestination = try await client.download(
            objectWithKey: sourceURL.relativePath,
            inBucket: bucketName,
            progressCallback: self.updateProgress
        )

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: tempDestination, to: destination)
    }

    func upload() async throws {
        print("Copying \(source) to \(destination)")

        guard
            let destinationURL = URL(string: self.destination),
            let bucketName = destinationURL.host
        else {
            abort()
        }

        let sourceURL = URL(fileURLWithPath: self.source)

        let key = destinationURL.path

        let client = try S3Client(credentials: .fromUserConfiguration())
        try await client.upload(
            objectAtPath: sourceURL,
            toBucket: bucketName,
            key: key,
            progressCallback: self.updateProgress
        )
    }

    func list() async throws {
        let client = try S3Client(credentials: .fromUserConfiguration())

        guard
            let url = URL(string: self.source),
            let bucket = url.host
        else {
            throw Errors.invalidSource
        }

        let prefix = String(url.path.trimmingPrefix("/"))

        for object in try await client.list(bucket: bucket, prefix: prefix).objects {
            print(object.key)
        }
    }

    func presign() throws {
        let client = try S3Client(credentials: .fromUserConfiguration())

        guard
            let url = URL(string: self.source),
            let bucket = url.host
        else {
            throw Errors.invalidSource
        }

        let key = String(url.path.trimmingPrefix("/"))

        print(client.signedDownloadUrl(forKey: key, in: bucket, validFor: 3600).absoluteString)
    }

    func head() async throws {
        let client = try S3Client(credentials: .fromUserConfiguration())

        guard
            let url = URL(string: self.source),
            let bucket = url.host
        else {
            throw Errors.invalidSource
        }

        let key = String(url.path.trimmingPrefix("/"))

        guard let object = try await client.head(bucket: bucket, key: key) else {
            print("Object not found")
            return
        }

        print("Key:\t\t\(object.key)")
        print("Size:\t\t\(format(fileSize: object.size))")
        print("eTag:\t\t\(object.eTag)")
        print("Last Modified:\t\(format(date: object.lastModifiedAt))")
    }

    func updateProgress(_ progress: Progress) {
        print(format(percentage: progress.fractionCompleted))
    }

    func resolveDestination() throws -> URL {
        if self.destination == "." {
            guard let sourceURL = URL(string: self.source) else {
                throw Errors.invalidSource
            }

            let pwd = FileManager.default.currentDirectoryPath
            return URL(fileURLWithPath: pwd).appendingPathComponent(sourceURL.lastPathComponent)
        }

        let destination = URL(fileURLWithPath: self.destination)
        if try FileManager.default.directoryExists(at: destination) {
            let url = URL(string: self.source)!
            return destination.appendingPathComponent(url.lastPathComponent)
        }

        if !FileManager.default.fileExists(atPath: self.destination) {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(self.destination)
        }

        throw Errors.unableToResolveDestination
    }

    func format(percentage: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.roundingMode = .down
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(for: percentage)!
    }

    func format(fileSize: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        return formatter.string(fromByteCount: Int64(fileSize))
    }

    func format(date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .long)
    }
}

extension FileManager {
    public func directoryExists(at url: URL) throws -> Bool {
        var isDir: ObjCBool = true
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

}
