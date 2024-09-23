import Foundation
import ArgumentParser

struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Data processing tasks",
        subcommands: [
            GenerateBuildkiteJobScript.self,
            GeneratePasswordCommand.self
        ]
    )
}
