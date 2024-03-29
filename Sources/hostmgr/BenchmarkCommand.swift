import Foundation
import ArgumentParser

struct BenchmarkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "benchmark",
        abstract: "System tests",
        subcommands: [
            NetworkBenchmark.self,
            DiskBenchmark.self
        ]
    )
}
