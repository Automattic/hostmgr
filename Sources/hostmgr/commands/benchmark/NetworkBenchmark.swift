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
        // Deprecated
    }
}
