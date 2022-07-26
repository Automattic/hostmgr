import Foundation
import ArgumentParser
import prlctl
import libhostmgr

struct GenerateBuildkiteJobScript: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "buildkite-job",
        abstract: "Generate a Buildkite Job Script"
    )

    func run() throws {
        let path = try FileManager.default.createTemporaryFile(containing: generateBuildScript()).path
        print(path)
    }

    func generateBuildScript() throws -> String {
        let exports = try generateExports()
            .map { "export \($0.key)=\"\($0.value.escapingQuotes())\"" }
            .joined(separator: "\n")

        return [
            "source ~/.circ",               // Need to source .circ first in order to set up the SSH session properly
            exports,                        // Declare all of our environment variables
            "buildkite-agent bootstrap"    // Then let's go!
        ].joined(separator: "\n")
    }

    // swiftlint:disable:next function_body_length
    func generateExports(
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> [String: String] {
        let copyableExports = environment.filter { $0.key.starts(with: "BUILDKITE") }

        return [
            // Manually specify the build path to keep them nice and clean in the output
            "BUILDKITE_BUILD_PATH": "/usr/local/var/buildkite-agent/builds",

            // Keep the agent name simple for better folder paths
            "BUILDKITE_AGENT_NAME": "builder",

            // Required to convince `fastlane` that we're running in CI
            "CI": "true",

            // Used by the S3 Git Mirror plugin
            "GIT_MIRROR_SERVER_ROOT": "http://\(try getIpAddress()):\( Configuration.shared.gitMirrorPort)"
        ]
        .merging(copyableExports, uniquingKeysWith: { lhs, _ in lhs })
        .compactMapValues { $0 }
    }

    // A somewhat hack-ey way to get the device's IP address, but it should continue
    // to work in future macOS versions for some time
    func getIpAddress(forInterface name: String = "en0") throws -> String {

        let output = Pipe()

        let task = Process()
        task.launchPath = "/usr/sbin/ipconfig"
        task.arguments = ["getifaddr", name]
        task.standardOutput = output
        try task.run()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
