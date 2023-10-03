import Foundation
import ArgumentParser
import Logging
import libhostmgr

private let startDate = Date()

struct NetworkBenchmark: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Test Network Speed"
    )

    func run() throws {
        Console.exit("Deprecated – use the `networkQuality` tool.", style: .error)
    }
}
