import Foundation
import ArgumentParser
import Logging
import libhostmgr

private let startDate = Date()

struct NetworkBenchmark: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Test Network Speed"
    )

    func run() async throws {
        let remoteImages = try await RemoteVMRepository.shared.listImages(sortedBy: .size)

        guard !remoteImages.isEmpty else {
            Console.error("Unable to find a remote image to use as a network benchmark")
            throw ExitCode(rawValue: -1)
        }

        Console.heading("Starting Benchmark")

        for remoteImage in remoteImages {
            let path = try await libhostmgr.downloadRemoteImage(remoteImage)
            try FileManager.default.removeItem(at: path)
        }
    }
}
