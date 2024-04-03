import Foundation

public struct AWSCredentials: Equatable {
    let accessKeyId: String
    let secretKey: String
    let region: String

    enum Error: Swift.Error, LocalizedError {
        case noProfileNamed(name: String)
        case missingRequiredKey(name: String)

        var errorDescription: String? {
            let msgSuffix = "in neither ~/.aws/config nor ~/.aws/credentials file"
            switch self {
            case .noProfileNamed(let name):
                return "No profile named `\(name)` \(msgSuffix)"
            case .missingRequiredKey(let name):
                return "Coundn't find key \(name) for requested profile \(msgSuffix)"
            }
        }
    }

    public init(accessKeyId: String, secretKey: String, region: String) {
        self.accessKeyId = accessKeyId
        self.secretKey = secretKey
        self.region = region
    }
}

extension AWSCredentials {
    /// Build `AWSCredentials` from the `~/.aws/config` and `~/.aws/credentials` user config files
    /// - Parameter profile: The name of the profile to get the credentials of
    /// - Returns: Credentials from combining the values from the user config files
    public static func fromUserConfiguration(profile: AWSProfile = .default) throws -> AWSCredentials {
        let configs: [AWSProfileConfig] = [
            // Note: values in ~/.aws/config takes precedence over values in `~/.aws/credentials`
            try? AWSProfileConfigFileParser.profilesFromConfigUserFile(),
            try? AWSProfileConfigFileParser.profilesFromCredentialsUserFile()
        ].compactMap({ $0?[profile.name] })

        if configs.isEmpty {
            throw Error.noProfileNamed(name: profile.name)
        }

        return try AWSCredentials.from(configs: configs)
    }

    /// Build `AWSCredentials` from a list of `AWSProfileConfig`, each representing a parsed profile from user config
    /// - Parameter configs: The list of profile configurations to search the credentials in.
    ///                      First ones take precedence over next ones
    /// - Returns: Credentials from combining the values from the provided profile configs
    static func from(configs: [AWSProfileConfig]) throws -> AWSCredentials {
        func value(key: AWSProfileConfig.Key) throws -> String {
            guard let value = configs.lazy.compactMap({ $0[key] }).first else {
                throw Error.missingRequiredKey(name: key.rawValue)
            }
            return value
        }

        return AWSCredentials(
            accessKeyId: try value(key: .accessKeyId),
            secretKey: try value(key: .secretKey),
            region: try value(key: .region)
        )
    }
}

public struct AWSProfile {
    let name: String

    public static func custom(name: String) -> AWSProfile {
        return AWSProfile(name: name)
    }

    public static let `default` = AWSProfile(name: "default")
}
