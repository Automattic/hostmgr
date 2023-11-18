import Foundation
import ArgumentParser
import libhostmgr

struct NetworkBenchmark: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Test Network Speed"
    )

    func run() throws {
        Console.exit("Deprecated – use the `networkQuality` tool.", style: .error)
    }
}
