import Foundation
import Crypto

// MARK: - XML Parsing Helpers

enum InvalidXMLResponseError: Error {
    case invalidRootNode(expected: String, got: String?)
    case missingElement(named: String)
    case multipleElements(named: String, found: [XMLElement])
    case unexpectedValue(String, inElement: String)
}

extension XMLDocument {
    func rootElement(expectedName: String) throws -> XMLElement {
        let root = self.rootElement()
        guard let root, root.name == expectedName else {
            throw InvalidXMLResponseError.invalidRootNode(expected: expectedName, got: root?.name)
        }
        return root
    }
}

extension XMLElement {
    func value<T>(forElementName name: String, transform: (String) -> T? = { $0 }) throws -> T {
        let nodes = self.elements(forName: name)
        guard nodes.count <= 1 else {
            throw InvalidXMLResponseError.multipleElements(named: name, found: nodes)
        }
        guard let text = nodes.first?.stringValue else {
            throw InvalidXMLResponseError.missingElement(named: name)
        }
        guard let value = transform(text) else {
            throw InvalidXMLResponseError.unexpectedValue(text, inElement: name)
        }
        return value
    }
}

extension String {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}

// MARK: - Date Parsing

func formattedTimestamp(from date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter.string(from: date)
}

func formattedDatestamp(from date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = "yyyyMMdd"
    return formatter.string(from: date)
}

func parseLastModifiedDate(_ string: String) -> Date? {
    let modificationDateParser = DateFormatter()
    modificationDateParser.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"
    return modificationDateParser.date(from: string)
}

func parseISO8601String(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string)
}

// MARK: - Parallel Loops

extension Collection {
    func parallelMap<T>(parallelism: Int, _ transform: @escaping (Element) async throws -> T) async throws -> [T] {

        let elementCount = self.count

        if elementCount == 0 {
            return []
        }

        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var result = [T?](repeatElement(nil, count: elementCount))

            var index = self.startIndex
            var submitted = 0

            func submitNext() async throws {
                if index == self.endIndex { return }

                group.addTask { [submitted, index] in
                    let value = try await transform(self[index])
                    return (submitted, value)
                }

                submitted += 1
                formIndex(after: &index)
            }

            // submit first initial tasks
            for _ in 0..<parallelism {
                try await submitNext()
            }

            // as each task completes, submit a new task until we run out of work
            while let (index, taskResult) = try await group.next() {
                result[index] = taskResult

                try Task.checkCancellation()
                try await submitNext()
            }

            assert(result.count == elementCount)
            return Array(result.compactMap { $0 })
        }
    }
}

// MARK: - Crypto Helpers

func sha256Hash(fileAt url: URL) throws -> String {
    var hasher = SHA256()

    let fileHandle = try FileHandle(forReadingFrom: url)
    var data = fileHandle.readData(ofLength: 4096)

    while data.count == 4096 {
        hasher.update(data: data)
        data = fileHandle.readData(ofLength: 4096)
    }

    return hasher.finalize().lowercaseHexValue
}

func sha256Hash(data: Data) -> String {
    var hasher = SHA256()
    hasher.update(data: data)
    return hasher.finalize().lowercaseHexValue
}

func sha256Hash(string: String) -> String {
    sha256Hash(data: Data(string.utf8))
}

func md5Hash(data: Data) -> String {
    var hasher = Insecure.MD5()
    hasher.update(data: data)
    return hasher.finalize().lowercaseHexValue
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }
}

extension Digest {
    var lowercaseHexValue: String {
        self.compactMap { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: -
extension Progress {

    #if(canImport(FoundationNetworking))
    // These methods don't exist in the Linux version of Foundation, so we implement them ourselves
    var throughput: Int? {
        self.userInfo[.throughputKey] as? Int
    }

    var estimatedTimeRemaining: TimeInterval? {
        self.userInfo[.estimatedTimeRemainingKey] as? TimeInterval
    }
    #endif

    func estimateThroughput(fromStartDate date: Date) {
        estimateThroughput(fromTimeElapsed: Date().timeIntervalSince(date))
    }

    func estimateThroughput(fromTimeElapsed elapsedTime: TimeInterval) {
        guard Int64(elapsedTime) > 0 else {
            self.setUserInfoObject(0, forKey: .throughputKey)
            self.setUserInfoObject(TimeInterval.infinity, forKey: .estimatedTimeRemainingKey)
            return
        }

        let unitsPerSecond = self.completedUnitCount.quotientAndRemainder(dividingBy: Int64(elapsedTime)).quotient
        let throughput = Int(unitsPerSecond)
        self.setUserInfoObject(throughput, forKey: .throughputKey)

        guard throughput > 0 else {
            self.setUserInfoObject(TimeInterval.infinity, forKey: .estimatedTimeRemainingKey)
            return
        }

        let unitsRemaining = self.totalUnitCount - self.completedUnitCount
        let secondsRemaining = unitsRemaining.quotientAndRemainder(dividingBy: Int64(throughput)).quotient

        self.setUserInfoObject(TimeInterval(secondsRemaining), forKey: .estimatedTimeRemainingKey)
    }

    static func from(_ int: Int) -> Progress {
        return Progress(totalUnitCount: Int64(int))
    }
}

// MARK: -
extension FileManager {
    var temporaryFile: URL {
        self.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func fileSize(of url: URL) throws -> Int {
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw CocoaError(.fileReadUnknown)
        }

        return size
    }
}

// MARK: - HTTP/URL Helpers
enum HTTPMethod: String {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case connect = "CONNECT"
    case options = "OPTIONS"
    case trace = "TRACE"
    case patch = "PATCH"
}

extension URLQueryItem {
    var escapedValue: String? {
        var characterSet = CharacterSet.urlQueryAllowed
        characterSet.remove("/")

        return value?
            .addingPercentEncoding(withAllowedCharacters: characterSet)?
            .replacingOccurrences(of: "/", with: "%2F")
    }
}

extension [URLQueryItem] {

    var asEscapedQueryString: String {
        self.map { "\($0.name)=\($0.escapedValue ?? "")" }.joined(separator: "&")
    }

    var escaped: [URLQueryItem] {
        self.map { URLQueryItem(name: $0.name, value: $0.escapedValue) }
    }

    func sorted() -> [URLQueryItem] {
        return sorted { lhs, rhs in
            lhs.name.lowercased() < rhs.name.lowercased()
        }
    }

    subscript(key: String) -> String? {
        return self.first { $0.name == key }?.value
    }

    static let empty: [URLQueryItem] = []
}
