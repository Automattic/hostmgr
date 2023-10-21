import Foundation
import ArgumentParser
import libhostmgr

struct VMStatsCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show VM usage stats"
    )

    let vmManager = VMManager()

    enum CodingKeys: CodingKey {}

    func run() async throws {
        let stats = try await vmManager.getVMUsageStats().grouped().asTable()

        if stats.isEmpty {
            Console.error("No VM stats found")
        } else {
            Console.printTable(data: stats, columnTitles: ["VM Name", "Count"])
        }
    }
}
