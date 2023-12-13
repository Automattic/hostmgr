import Foundation

public struct AWSCredentials: Equatable {

    let accessKeyId: String
    let secretKey: String
    let region: String

    public init(accessKeyId: String, secretKey: String, region: String) {
        self.accessKeyId = accessKeyId
        self.secretKey = secretKey
        self.region = region
    }

    public static func fromUserConfiguration(profile: AWSProfile = .default) throws -> AWSCredentials {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws")
            .appendingPathComponent("credentials")

        return try from(url: url, profile: profile)
    }

    public static func configurationFileAt(_ url: URL, containsProfileNamed name: String) throws -> Bool {
        let credentialsFile = try AWSCredentialsFileParser(path: url).parse()
        return credentialsFile[name] != nil
    }

    public static func from(url: URL, profile: AWSProfile = .default) throws -> AWSCredentials {
        let credentialsFile = try AWSCredentialsFileParser(path: url).parse()
        guard let profile = credentialsFile[profile.name] else {
            throw AWSCredentialsError.noProfileNamed(name: profile.name)
        }
        return profile
    }
}

public struct AWSProfile {
    let name: String

    public static func custom(name: String) -> AWSProfile {
        return AWSProfile(name: name)
    }

    public static let `default` = AWSProfile(name: "default")
}
