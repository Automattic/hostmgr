import Foundation
import libhostmgr
import tinys3

protocol HttpResponse {
    var responseCode: Int { get }
}

protocol HttpDataResponse: HttpResponse {
    func fetchData() throws -> Data?
}

protocol HttpTextResponse: HttpDataResponse {
    var text: String { get }
}

extension HttpTextResponse {
    func fetchData() throws -> Data? {
        Data(self.text.utf8)
    }
}

protocol StreamableHttpResponse: HttpResponse {
    func stream(
        headersCallback: @escaping HeaderCallback,
        dataCallback: @escaping DataCallback
    ) async throws
}

// MARK: Concrete Types
struct HttpErrorResponse: HttpTextResponse {
    let responseCode: Int

    var text: String { HTTPURLResponse.localizedString(forStatusCode: self.responseCode) }

    static let invalidRequest = HttpErrorResponse(responseCode: 400)
    static let notFound = HttpErrorResponse(responseCode: 404)
    static let serverError = HttpErrorResponse(responseCode: 500)
}

struct HttpEmptyResponse: HttpResponse {
    let responseCode: Int

    func fetchData() throws -> Data? {
        return Data()
    }
}

struct HttpCodableResponse: HttpDataResponse {
    let responseCode: Int = 200
    let rootObject: Codable

    func fetchData() throws -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self.rootObject)
    }
}

class HttpStreamingDownloadResponse: StreamableHttpResponse {
    let responseCode: Int
    let source: URL
    let destination: URL

    init(responseCode: Int, source: URL, destination: URL) {
        self.responseCode = responseCode
        self.source = source
        self.destination = destination
    }

    func stream(
        headersCallback: @escaping HeaderCallback,
        dataCallback: @escaping DataCallback
    ) async throws {
        let operation = StreamingDownloadOperation(url: self.source)
        operation.dataCallback = dataCallback
        operation.headersCallback = headersCallback
        try await operation.start(tempPath: destination)
    }
}

struct HttpStreamingFileResponse: StreamableHttpResponse {
    var responseCode: Int
    let filePath: URL

    func stream(
        headersCallback: @escaping HeaderCallback,
        dataCallback: @escaping DataCallback
    ) async throws {

        let fileSize = try FileManager.default.size(ofObjectAt: filePath)

        headersCallback([
            "Content-Length": String(fileSize),
            "Content-Type": "application/octet-stream",
            "Content-Disposition": "attachment;filename=\"\(filePath.lastPathComponent)\""
        ])

        let reader = try StreamingFileReader(url: self.filePath)
        while let data = reader.stream() {
            dataCallback(data)
        }
    }

    struct StreamingFileReader {

        private let fileHandle: FileHandle
        private let bufferSize: Int

        init(url: URL, bufferSize: Int = 16384) throws {
            self.fileHandle = try FileHandle(forReadingFrom: url)
            self.bufferSize = bufferSize
        }

        func stream() -> Data? {
            let chunk = self.fileHandle.readData(ofLength: self.bufferSize)

            if chunk.isEmpty {
                return nil
            }

            return chunk
        }
    }
}
