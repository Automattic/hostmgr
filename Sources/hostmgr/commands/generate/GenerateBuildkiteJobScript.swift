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
            .map { "export \($0.key)=\"\($0.value)\"" }
            .joined(separator: "\n")

        return [
            "source ~/.circ",               // Need to source .circ first in order to set up the SSH session properly
            exports,                        // Declare all of our environment variables
            "buildkite-agent bootstrap",    // Then let's go!
        ].joined(separator: "\n")
    }

    // swiftlint:disable:next function_body_length
    func generateExports(from environment: [String: String] = ProcessInfo.processInfo.environment) throws -> [String: String] {

        // See https://buildkite.com/docs/pipelines/environment-variables for
        // and up-to-date list of environment variables that Buildkite exports
        let copyableExports = [
            "BUILDKITE",
            "BUILDKITE_JOB_ID",
            "BUILDKITE_REPO",
            "BUILDKITE_COMMIT",
            "BUILDKITE_BRANCH",
            "BUILDKITE_TAG",
            "BUILDKITE_REFSPEC",
            "BUILDKITE_PULL_REQUEST",
            "BUILDKITE_PULL_REQUEST_REPO",
            "BUILDKITE_AGENT_META_DATA_QUEUE",
            "BUILDKITE_ORGANIZATION_SLUG",
            "BUILDKITE_PIPELINE_SLUG",
            "BUILDKITE_PIPELINE_PROVIDER",
            "BUILDKITE_ARTIFACT_PATHS",
            "BUILDKITE_ARTIFACT_UPLOAD_DESTINATION",
            "BUILDKITE_CLEAN_CHECKOUT",
            "BUILDKITE_GIT_CLONE_FLAGS",
            "BUILDKITE_HOOKS_PATH",
            "BUILDKITE_AGENT_INCLUDE_RETRIED_JOBS",
            "BUILDKITE_AGENT_ENDPOINT",
            "BUILDKITE_NO_HTTP2",
            "BUILDKITE_AGENT_DEBUG_HTTP",
            "BUILDKITE_AGENT_NO_COLOR",
            "BUILDKITE_AGENT_DEBUG",
            "BUILDKITE_AGENT_PROFILE",
            "BUILDKITE_BOOTSTRAP_PHASES",
            "BUILDKITE_LABEL",
            "BUILDKITE_AGENT_NAME",

            /// These ones aren't printed as part of the default list – we're copying them so that `bootstrap` works
            "BUILDKITE_AGENT_ACCESS_TOKEN",
            "BUILDKITE_BUILD_ID",
            "BUILDKITE_PLUGINS_PATH",

        ].reduce([String: String]()) { dictionary, key in
            var mutableDictionary = dictionary
            mutableDictionary[key] = environment[key]
            return mutableDictionary
        }

        return [
            /// Manually specify the build path to keep them nice and clean in the output
            "BUILDKITE_BUILD_PATH": "/usr/local/var/buildkite-agent/builds",

            /// Keep the agent name simple for better folder paths
            "BUILDKITE_AGENT_NAME": "builder",

            /// Required to convince `fastlane` that we're running in CI
            "CI": "true",

            /// We need to escape double slashes in the command / script, otherwise we can't pass it via command line
            "BUILDKITE_COMMAND": environment["BUILDKITE_COMMAND"]?.escapingQuotes(),
            "BUILDKITE_SCRIPT_PATH": environment["BUILDKITE_SCRIPT_PATH"]?.escapingQuotes(),

            /// We need to escape double slashes in the Buildkite Plugins JSON, otherwise it causes an inscrutable error like:
            /// ```
            /// Error: Failed to parse a plugin definition: invalid character 'g' looking for beginning of object key string
            /// ```
            "BUILDKITE_PLUGINS": environment["BUILDKITE_PLUGINS"]?.escapingQuotes(),

            /// Used by the S3 Git Mirror plugin
            "GIT_MIRROR_SERVER_ROOT": "http://\(try getIpAddress()):\( Configuration.shared.gitMirrorPort)",
        ]
        .merging(copyableExports, uniquingKeysWith: { lhs, rhs in lhs })
        .compactMapValues { $0 }
    }

    /// A somewhat hack-ey way to get the device's IP address, but it should continue to work in future macOS versions for some time
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
