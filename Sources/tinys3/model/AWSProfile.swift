/// The name of an AWS profile name, wrapped in a strong type just for nicer type-safety
public struct AWSProfile: ExpressibleByStringLiteral, Hashable {
    let name: String

    public init(name: String) {
        self.name = name
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(name: value)
    }

    public static let `default` = AWSProfile(name: "default")
}

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
