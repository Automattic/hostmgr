import Foundation
import ArgumentParser
import tinys3

public struct Configuration: Codable {

    public enum AWSConfigurationType: String, Codable {
        case configurationFile
        case ec2Environment
    }

    struct Defaults {
        static let defaultAWSAcceleratedTransferAllowed = true
        static let defaultAWSConfigurationMethod: AWSConfigurationType = .configurationFile
        static let defaultAuthorizedKeysRefreshInterval: UInt = 3600
    }

    public var version = 1

    /// VM Remote Image Settings
    public var vmImagesBucket: String = ""
    public var vmImagesEndpoint: S3Endpoint {
        allowAWSAcceleratedTransfer ? S3Endpoint.accelerated : S3Endpoint.default
    }

    /// Images that are protected from deletion (useful for local work, or for a fallback image)
    public var protectedImages: [String] = []

    /// authorized_keys file sync
    public var authorizedKeysSyncInterval = Defaults.defaultAuthorizedKeysRefreshInterval
    public var authorizedKeysBucket = ""

    /// git repo mirroring
    public var gitMirrorBucket = ""
    public var gitMirrorEndpoint: S3Endpoint {
        allowAWSAcceleratedTransfer ? S3Endpoint.accelerated : S3Endpoint.default
    }

    /// settings for running in AWS
    public var allowAWSAcceleratedTransfer: Bool! = Defaults.defaultAWSAcceleratedTransferAllowed
    public var awsConfigurationMethod: AWSConfigurationType! = Defaults.defaultAWSConfigurationMethod

    // MARK: VM Resource Settings

    /// Should this node run more than one concurrent VM?
    public let isSharedNode: Bool = false

    /// How much RAM should be reserved for the host (and not allocated to VMs)
    public let hostReservedRAM: UInt64 = 1024 * 1024 * 2048 // Leave 2GB for the VM host

    enum CodingKeys: String, CodingKey {
        case version

        case vmImagesBucket
        case gitMirrorBucket

        case authorizedKeysSyncInterval
        case authorizedKeysBucket


        case allowAWSAcceleratedTransfer
        case awsConfigurationMethod
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = 1

        vmImagesBucket = try values.decode(String.self, forKey: .vmImagesBucket)

        authorizedKeysSyncInterval = values.decode(forKey: .authorizedKeysSyncInterval, defaultingTo: 3600)
        authorizedKeysBucket = try values.decode(String.self, forKey: .authorizedKeysBucket)

        gitMirrorBucket = try values.decode(String.self, forKey: .gitMirrorBucket)

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
        do {
            return try ConfigurationRepository.getConfiguration()
        } catch {
            Console.error("Unable to load configuration: \(error.localizedDescription)")
            Foundation.exit(-1)
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
