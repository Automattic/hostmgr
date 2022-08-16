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
        var scriptBuilder = BuildkiteScriptBuilder()

        scriptBuilder.addDependency(atPath: "~/.circ")
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE", value: "true")
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_")
        scriptBuilder.addCommand("buildkite-agent bootstrap")

        // Manually specify the build path to keep them nice and clean in the output
        scriptBuilder.addEnvironmentVariable(
            named: "BUILDKITE_BUILD_PATH",
            value: "/usr/local/var/buildkite-agent/builds"
        )

        // Keep the agent name simple for better folder paths
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE_AGENT_NAME", value: "builder")

        // Required to convince `fastlane` that we're running in CI
        scriptBuilder.addEnvironmentVariable(named: "CI", value: "true")

        // Used by the S3 Git Mirror plugin
        scriptBuilder.addEnvironmentVariable(
            named: "GIT_MIRROR_SERVER_ROOT",
            value: "http://\(try getIpAddress()):\( Configuration.shared.gitMirrorPort)"
        )

        let scriptText = scriptBuilder.build()

        let path = try FileManager.default.createTemporaryFile(containing: scriptText).path
        print(path)
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
