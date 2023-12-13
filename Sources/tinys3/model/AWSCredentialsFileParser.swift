import Foundation

struct AWSCredentialsFile {
    let profiles: [String: AWSCredentials]

    subscript(name: String) -> AWSCredentials? {
        return self.profiles[name]
    }
}

enum AWSCredentialsError: Error, LocalizedError {
    case fileDoesNotExist(url: URL)
    case noProfileNamed(name: String)
    case noRegionFound

    var errorDescription: String? {
        switch self {
        case .fileDoesNotExist(let url): return "There is no credentials file at \(url.path)"
        case .noProfileNamed(let name): return "No profile named `\(name)`"
        case .noRegionFound: return "No region set in your credentials file – please specify the region"
        }
    }
}

class AWSCredentialsFileParser {

    enum CredentialFileKey: String {
        case accessKeyId = "aws_access_key_id"
        case secretKey   = "aws_secret_access_key"
        case region      = "region"
    }

    /// Credentials File
    private let fileContents: String

    /// Parser Elements
    var profileName: String?
    var accessKeyId: String?
    var secretKey: String?
    var region: String?

    var profiles = [String: AWSCredentials]()

    init(path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AWSCredentialsError.fileDoesNotExist(url: path)
        }

        self.fileContents = try String(contentsOf: path)
    }

    init(string: String) {
        self.fileContents = string
    }

    func parse() throws -> AWSCredentialsFile {
        let lines = self
            .fileContents
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } // Properly handle trailing whitespace
            .map { $0.components(separatedBy: "#").first }
            .compactMap { $0 }
            .filter { !$0.starts(with: "#") } // Don't parse comments
            .filter { !$0.isEmpty }

        for line in lines {
            if lineIsHeader(line) {
                try self.processCredentials()
                self.profileName = convertLineToProfileName(line)
                continue
            }

            guard let kvp = convertLineToKeyValuePairs(line) else {
                continue
            }

            switch kvp.0 {
            case .accessKeyId: self.accessKeyId = kvp.1
            case .secretKey: self.secretKey = kvp.1
            case .region: self.region = kvp.1
            }
        }

        try self.processCredentials()

        return AWSCredentialsFile(profiles: self.profiles)
    }

    func lineIsHeader(_ line: String) -> Bool {
        line.starts(with: "[") && line.hasSuffix("]")
    }

    func convertLineToProfileName(_ line: String) -> String {
        line
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
    }

    func convertLineToKeyValuePairs(_ line: String) -> (CredentialFileKey, String)? {
        guard line.contains("=") else {
            return nil
        }

        let components = line
            .components(separatedBy: "=")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
            .filter { !$0.isEmpty }

        guard
            components.count == 2,
            let stringKey = components.first,
            let key = CredentialFileKey(rawValue: stringKey),
            let value = components.last
        else {
            return nil
        }

        return (key, value)
    }

    func processCredentials() throws {

        defer {
            self.resetParser()
        }

        guard
            let profileName = self.profileName,
            let accessKeyId = self.accessKeyId,
            let secretKey = self.secretKey
        else {
            return
        }

        guard let region = self.region else {
            throw AWSCredentialsError.noRegionFound
        }

        self.profiles[profileName] = AWSCredentials(
            accessKeyId: accessKeyId,
            secretKey: secretKey,
            region: region
        )
    }

    func resetParser() {
        self.accessKeyId = nil
        self.secretKey = nil
        self.region = nil
        self.profileName = nil
    }
}
