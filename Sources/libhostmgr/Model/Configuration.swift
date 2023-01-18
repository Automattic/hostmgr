import Foundation
import ArgumentParser

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

        static let defaultSyncTasks: [SchedulableSyncCommand] = [
            .authorizedKeys,
            .vmImages
        ]

        static let defaultGitMirrorPort: UInt = 41362

        static let defaultAWSAcceleratedTransferAllowed = true
        static let defaultAWSConfigurationMethod: AWSConfigurationType = .configurationFile

        static let defaultAuthorizedKeysRefreshInterval: UInt = 3600
    }

    public var version = 1

    public var syncTasks = Defaults.defaultSyncTasks

    /// VM Remote Image Settings
    public var vmImagesBucket: String = ""
    public var vmImagesRegion: String = "us-east-1"

    /// Images that are protected from deletion (useful for local work, or for a fallback image)
    public var protectedImages: [String] = []

    /// authorized_keys file sync
    public var authorizedKeysSyncInterval = Defaults.defaultAuthorizedKeysRefreshInterval
    public var authorizedKeysBucket = ""
    public var authorizedKeysRegion: String = "us-east-1"

    /// git repo mirroring
    public var gitMirrorBucket = ""
    public var gitMirrorPort = Defaults.defaultGitMirrorPort

    /// settings for running in AWS
    public var allowAWSAcceleratedTransfer: Bool! = Defaults.defaultAWSAcceleratedTransferAllowed
    public var awsConfigurationMethod: AWSConfigurationType! = Defaults.defaultAWSConfigurationMethod

    enum CodingKeys: String, CodingKey {
        case version
        case syncTasks

        case vmImagesBucket
        case vmImagesRegion

        case protectedImages

        case authorizedKeysSyncInterval
        case authorizedKeysBucket
        case authorizedKeysRegion

        case gitMirrorBucket
        case gitMirrorPort

        case allowAWSAcceleratedTransfer
        case awsConfigurationMethod
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = 1
        syncTasks = values.decode(
            forKey: .syncTasks,
            defaultingTo: Defaults.defaultSyncTasks
        )

        vmImagesBucket = try values.decode(String.self, forKey: .vmImagesBucket)
        vmImagesRegion = try values.decode(String.self, forKey: .vmImagesRegion)

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

    static var shared: Configuration = (try? ConfigurationRepository.getConfiguration()) ?? Configuration()

    static var isValid: Bool {
        let configuration = try? ConfigurationRepository.getConfiguration()
        return configuration != nil
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
