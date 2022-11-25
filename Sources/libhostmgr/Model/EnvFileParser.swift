import Foundation

struct EnvFile {
    var configuration: [String: String]

    static func from(_ url: URL) throws -> EnvFile {
        try EnvFileParser(string: String(contentsOf: url)).parse()
    }

    static func from(_ string: String) throws -> EnvFile {
        try EnvFileParser(string: string).parse()
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

    func parse() throws -> EnvFile {
        let pairs = try self.string
            .components(separatedBy: "\n")
            .compactMap(convertLineToKeyValuePair)
            .reduce(into: [String: String]()) { $0[$1.0] = $1.1 }

        return EnvFile(configuration: pairs)
    }

    func convertLineToKeyValuePair(_ line: String) throws -> (String, String)? {
        let trimmedLine = line.trimmingWhitespace
        if trimmedLine.isEmpty {
            return nil
        }

        guard let separatorIndex = line.firstIndex(of: "=") else {
            return nil
        }

        let startOfValueIndex = line.index(separatorIndex, offsetBy: 1)

        let key = String(line[..<separatorIndex]).trimmingWhitespace
        let value = String(line[startOfValueIndex...]).trimmingWhitespace

        if let quotedValue = try extractQuotedPortionOfValue(value) {
            return (key, quotedValue)
        }

        if let indexOfCommentMarker = value.firstIndex(of: "#") {
            return (key, String(value[..<indexOfCommentMarker]).trimmingWhitespace)
        }

        return (key, value)
    }

    func extractQuotedPortionOfValue(_ value: String) throws -> String? {
        let expression = try NSRegularExpression(pattern: #"^"(?<string>.*)""#)
        return expression.firstMatch(named: "string", in: value)
    }
}
