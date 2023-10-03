import Foundation
import ArgumentParser
import tinys3

public struct Configuration: Codable {

    public enum SchedulableSyncCommand: String, Codable, CaseIterable, ExpressibleByArgument {
        case authorizedKeys = "authorized_keys"
        case vmImages = "vm_images"
    }

    public enum AWSConfigurationType: String, Codable {
        case configurationFile
        case ec2Environment
    }

    struct Defaults {
        static let defaultGitMirrorPort: UInt = 41362

        static let defaultAWSAcceleratedTransferAllowed = true
        static let defaultAWSConfigurationMethod: AWSConfigurationType = .configurationFile

        static let defaultAuthorizedKeysRefreshInterval: UInt = 3600
    }

    public var version = 1

    /// VM Remote Image Settings
    public var vmImagesBucket: String = ""
    public var vmImagesRegion: String = "us-east-1"
    public var vmImagesEndpoint: S3Endpoint = .accelerated

    /// Images that are protected from deletion (useful for local work, or for a fallback image)
    public var protectedImages: [String] = []

    /// authorized_keys file sync
    public var authorizedKeysSyncInterval = Defaults.defaultAuthorizedKeysRefreshInterval
    public var authorizedKeysBucket = ""
    public var authorizedKeysRegion: String = "us-east-1"

    /// git repo mirroring
    public var gitMirrorBucket = ""
    public var gitMirrorPort = Defaults.defaultGitMirrorPort
    public var gitMirrorRegion: String = "us-east-1"
    public var gitMirrorEndpoint: S3Endpoint = .accelerated

    /// settings for running in AWS
    public var allowAWSAcceleratedTransfer: Bool! = Defaults.defaultAWSAcceleratedTransferAllowed
    public var awsConfigurationMethod: AWSConfigurationType! = Defaults.defaultAWSConfigurationMethod

    /// VM Memory Settings
    public var hostReservedRAM = 1024 * 1024 * 4096 // Leave 4GB for the VM host

    enum CodingKeys: String, CodingKey {
        case version

        case vmImagesBucket
        case vmImagesRegion
        case vmImagesEndpoint

        case protectedImages

        case authorizedKeysSyncInterval
        case authorizedKeysBucket
        case authorizedKeysRegion

        case gitMirrorBucket
        case gitMirrorPort
        case gitMirrorRegion
        case gitMirrorEndpoint

        case allowAWSAcceleratedTransfer
        case awsConfigurationMethod
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = 1

        vmImagesBucket = try values.decode(String.self, forKey: .vmImagesBucket)
        vmImagesRegion = try values.decode(String.self, forKey: .vmImagesRegion)
        let vmImagesEndpointString = try values.decode(String.self, forKey: .vmImagesEndpoint)
        vmImagesEndpoint = vmImagesEndpointString == "acccelerated" ? .accelerated : .default

        protectedImages = values.decode(
            forKey: .protectedImages,
            defaultingTo: [])

        authorizedKeysSyncInterval = values.decode(forKey: .authorizedKeysSyncInterval, defaultingTo: 3600)
        authorizedKeysBucket = try values.decode(String.self, forKey: .authorizedKeysBucket)
        authorizedKeysRegion = try values.decode(String.self, forKey: .authorizedKeysRegion)

        gitMirrorBucket = try values.decode(String.self, forKey: .gitMirrorBucket)
        gitMirrorPort = values.decode(
            forKey: .gitMirrorPort,
            defaultingTo: Defaults.defaultGitMirrorPort
        )
        gitMirrorRegion = try values.decode(String.self, forKey: .gitMirrorRegion)
        let gitMirrorEndpointString = try values.decode(String.self, forKey: .gitMirrorEndpoint)
        gitMirrorEndpoint = gitMirrorEndpointString == "acccelerated" ? .accelerated : .default

        allowAWSAcceleratedTransfer = values.decode(
            forKey: .allowAWSAcceleratedTransfer,
            defaultingTo: Defaults.defaultAWSAcceleratedTransferAllowed
        )
        awsConfigurationMethod = values.decode(
            forKey: .awsConfigurationMethod,
            defaultingTo: Defaults.defaultAWSConfigurationMethod
        )
    }
}

/// Accessor Helpers
public extension Configuration {

    static var shared: Configuration {
        get {
            try! ConfigurationRepository.getConfiguration()
        }
    }

    static func validate() throws {
        _ = try ConfigurationRepository.getConfiguration()
    }

    @discardableResult
    func save() throws -> Configuration {
        return try ConfigurationRepository.write(configuration: self)
    }

    static func from(data: Data) throws -> Self {
        try JSONDecoder().decode(Configuration.self, from: data)
    }
}

private extension KeyedDecodingContainer {

    func decode<T: Decodable>(forKey key: KeyedDecodingContainer<K>.Key, defaultingTo defaultValue: T) -> T {
        do {
            return try self.decode(T.self, forKey: key)
        } catch {
            return defaultValue
        }
    }
}

extension S3Endpoint: Encodable {
    enum Errors: Error {
        case invalidEndpoint
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if self == .accelerated {
            try container.encode("accelerated")
        }

        if self == .default {
            try container.encode("default")
        }

        throw Errors.invalidEndpoint
    }
}
