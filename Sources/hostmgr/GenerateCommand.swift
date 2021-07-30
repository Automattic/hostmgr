import Foundation
import ArgumentParser

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Data processing tasks",
        subcommands: [
            GenerateBuildkiteJobScript.self,
            GenerateGitMirrorManifestCommand.self,
            GeneratePasswordCommand.self,
        ]
    )
}
