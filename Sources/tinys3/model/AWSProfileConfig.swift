import Foundation

/// A list of key-value pairs representing AWS configuration values for a given (single) profile
struct AWSProfileConfig {
    let values: [String: String]

    enum Key: String {
        case accessKeyId = "aws_access_key_id"
        case secretKey   = "aws_secret_access_key"
        case region      = "region"
    }

    subscript(key: String) -> String? {
        return self.values[key]
    }

    subscript(key: Key) -> String? {
        return self[key.rawValue]
    }
}

extension AWSProfileConfig {
    /// Parses the `~/.aws/credentials` file for profiles and their associated configuration values
    /// - Returns: A dictionary containing an `AWSProfileConfig` for each profile name found
    static func profilesFromCredentialsUserFile() throws -> [String: AWSProfileConfig] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws")
            .appendingPathComponent("credentials")
        return try profiles(from: url, isCredentialsFile: true)
    }

    /// Parses the `~/.aws/config` file for profiles and their associated configuration values
    /// - Returns: A dictionary containing an `AWSProfileConfig` for each profile name found
    static func profilesFromConfigUserFile() throws -> [String: AWSProfileConfig] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws")
            .appendingPathComponent("config")
        return try profiles(from: url, isCredentialsFile: false)
    }

    /// Parses the profiles and their associated configuration values from a given file
    /// - Parameters:
    ///   - path: The URL of the file to parse
    ///   - isCredentialsFile: Indicates if the file to parse is a credentials file (true) or a config file (false)
    /// - Returns: A dictionary containing an `AWSProfileConfig` for each profile name found
    static func profiles(from path: URL, isCredentialsFile: Bool) throws -> [String: AWSProfileConfig] {
        try profiles(from: String(contentsOf: path), isCredentialsFile: isCredentialsFile)
    }

    /// Parses the profiles and their associated configuration values from a given string
    ///
    /// See [the AWS Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
    ///
    /// - Parameters:
    ///   - string: The content of the file to parse
    ///   - isCredentialsFile: Indicates if the file to parse is a credentials file (true) or a config file (false)
    /// - Returns: A dictionary containing an `AWSProfileConfig` for each profile name found
    static func profiles(from string: String, isCredentialsFile: Bool) throws -> [String: AWSProfileConfig] {
        var currentProfileName: String?
        var currentKeyValuePairs: [String: String] = [:]
        var profiles = [String: [String: String]]()

        func isSectionHeader(line: String) -> Bool {
            line.first == "[" && line.last == "]"
        }

        func parseProfileHeader(line: String) -> String? {
            if line == "[default]" {
                return "default" // Even in config files, default profile is [default] not [profile default]
            }
            let regex = isCredentialsFile ? /\[(\w+)\]/ : /\[profile (\w+)\]/
            let match = try? regex.wholeMatch(in: line)?.output.1
            return match.map(String.init)
        }

        func parseKeyValuePair(line: String) -> (String, String)? {
            let regex = /(\w+)\s*=\s*(.+)/
            let match = try? regex.wholeMatch(in: line)?.output
            return match.map { (String($0.1), String($0.2)) }
        }

        func storePendingSection() {
            if let key = currentProfileName {
                profiles[key] = currentKeyValuePairs
                currentKeyValuePairs.removeAll()
                currentProfileName = nil
            }
        }

        let lines = string
            .components(separatedBy: "\n")
            .map { $0.prefix(while: { $0 != "#" }) } // remove trailing comments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            if isSectionHeader(line: line) {
                storePendingSection()
                currentProfileName = parseProfileHeader(line: line)
            } else if currentProfileName != nil, let (key, value) = parseKeyValuePair(line: line) {
                currentKeyValuePairs[key] = value
            }
        }
        storePendingSection()

        return profiles.mapValues { AWSProfileConfig(values: $0) }
    }
}
