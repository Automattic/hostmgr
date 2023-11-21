import Foundation
import ArgumentParser
import tinys3
import Network

public struct Configuration: Codable {

    public var version = 1

    // MARK: authorized_keys sync
    public var authorizedKeysBucket: String

    // MARK: git repo mirroring
    public var gitMirrorBucket: String
    public var gitMirrorEndpoint: S3Endpoint {
        guard let allowAWSAcceleratedTransfer else {
            return .default
        }

        return allowAWSAcceleratedTransfer ? S3Endpoint.accelerated : S3Endpoint.default
    }

    // MARK: VM Remote Image Settings
    public var vmImagesBucket: String
    public var vmImagesEndpoint: S3Endpoint {
        guard let allowAWSAcceleratedTransfer else {
            return .default
        }

        return allowAWSAcceleratedTransfer ? S3Endpoint.accelerated : S3Endpoint.default
    }

    // MARK: AWS Settings
    public var allowAWSAcceleratedTransfer: Bool?

    // MARK: Cache Server Settings

    /// Where we should try to fetch cache items from
    ///
    public var cacheServerHostname: String?

    /// We might not have a DNS-routable address to the cache server, so allow specifying an IP address too
    ///
    public var cacheServerAddress: IPv4Address?

    // MARK: VM Resource Settings

    /// Should this node run more than one concurrent VM?
    private var isSharedNode: Bool?

    /// How much RAM should be reserved for the host (and not allocated to VMs)
    private var hostReservedRAM: UInt64?

    /// Alias of the `isSharedNode` configuration item – allows not specifying it in the config
    ///
    public var allowsMultipleVMs: Bool {
        isSharedNode ?? false
    }

    /// Alias of the `hostReservedRAM` configuration key – allows not specifying it in the config
    ///
    public var hostReservedRAMBytes: UInt64 {
        hostReservedRAM ?? 1024 * 1024 * 2048 // Leave 2GB for the VM host
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
