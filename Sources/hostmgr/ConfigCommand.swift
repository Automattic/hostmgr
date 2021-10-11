import Foundation
import ArgumentParser
import libhostmgr

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Display the system configuration"
    )

    func run() throws {
        let configuration = Configuration.shared

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let encoded = try encoder.encode(configuration)
        print(String(data: encoded, encoding: .utf8)!)
    }
}
