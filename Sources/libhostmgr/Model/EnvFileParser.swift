import Foundation

struct EnvFile {
    var configuration: [String: String]

    static func from(_ url: URL) throws -> EnvFile {
        try EnvFileParser(string: String(contentsOf: url)).parse()
    }

    static func from(_ string: String) -> EnvFile {
        EnvFileParser(string: string).parse()
    }

    subscript(key: String) -> String? {
        configuration[key]
    }

    /// Apply the values in the `.env` file to the environment
    func apply() {
        var environmentCopy = ProcessInfo.processInfo.environment
        for (key,value) in self.configuration {
            environmentCopy[key] = value
        }
        Process().environment = environmentCopy
    }
}

class EnvFileParser {

    private let string: String

    init(string: String) {
        self.string = string
    }

    func parse() -> EnvFile {
        let pairs = self.string
            .components(separatedBy: "\n")
            .compactMap(convertLineToKeyValuePair)
            .reduce(into: [String: String]()) { $0[$1.0] = $1.1 }

        return EnvFile(configuration: pairs)
    }

    func convertLineToKeyValuePair(_ line: String) -> (String, String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty {
            return nil
        }

        guard let separatorIndex = line.firstIndex(of: "=") else {
            return nil
        }

        let startOfValueIndex = line.index(separatorIndex, offsetBy: 1)

        let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        var value = String(line[startOfValueIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Trim quotes if needed
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }

        return (key, value)
    }
}
