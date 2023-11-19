import Foundation
import ArgumentParser
import libhostmgr

struct GenerateBuildkiteJobScript: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "buildkite-job",
        abstract: "Generate a Buildkite Job Script"
    )

    private let username = "builder"

    private var overriddenKeys: [String: String] {
        [
            // Manually specify the build path to keep paths nice and clean in the output
            "BUILDKITE_BUILD_PATH": Paths.buildkiteBuildDirectory.path,
            "BUILDKITE_HOOKS_PATH": Paths.buildkiteHooksDirectory.path,
            "BUILDKITE_PLUGINS_PATH": Paths.buildkitePluginsDirectory.path,
            "BUILDKITE_GIT_MIRRORS_PATH": "/Volumes/My Shared Files/git-mirrors",
            "BUILDKITE_GIT_MIRRORS_SKIP_UPDATE": "true"   // The agent can't write to the Git Mirror, so don't try
        ]
    }

    private let disallowedKeys = [
        "BUILDKITE_BIN_PATH",
        "BUILDKITE_BUILD_CHECKOUT_PATH",
        "BUILDKITE_CONFIG_PATH"
    ]

    enum CodingKeys: CodingKey {}

    func run() throws {
        var scriptBuilder = BuildkiteScriptBuilder()

        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE", value: "true")
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_")

        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE_BIN_PATH", value: "/usr/local/bin")
        scriptBuilder.addEnvironmentVariable(
            named: "BUILDKITE_BUILD_CHECKOUT_PATH",
            value: "/usr/local/var/buildkite-agent/builds/\(hostname)/\(buildkiteOrganization)\(buildkitePipelineSlug)"
        )

        scriptBuilder.addEnvironmentVariable(
            named: "BUILDKITE_HOOKS_PATH",
            value: "/usr/local/etc/buildkite-agent/hooks"
        )

        scriptBuilder.addEnvironmentVariable(
            named: "BUILDKITE_PLUGINS_PATH",
            value: "/usr/local/var/buildkite-agent/plugins"
        )

        scriptBuilder.addEnvironmentVariable(
            named: "PATH",
            value: "/opt/homebrew/bin:/opt/ci/bin:$PATH"
        )

        scriptBuilder.addCommand("buildkite-agent bootstrap")

        for (key, value) in overriddenKeys {
            scriptBuilder.addEnvironmentVariable(named: key, value: value)
        }

        for key in disallowedKeys {
            scriptBuilder.removeEnvironmentVariable(named: key)
        }

        // Keep the agent name simple for better folder paths
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE_AGENT_NAME", value: username)

        // Required to convince `fastlane` that we're running in CI
        scriptBuilder.addEnvironmentVariable(named: "CI", value: "true")

        let scriptText = scriptBuilder.build()

        let path = try FileManager.default.createTemporaryFile(containing: scriptText).path
        print(path)
    }

    let hostname: String = Host.current().name!

    var buildkiteOrganization: String {
        ProcessInfo.processInfo.environment["BUILDKITE_ORGANIZATION_SLUG"]!
    }

    var buildkitePipelineSlug: String {
        ProcessInfo.processInfo.environment["BUILDKITE_PIPELINE_SLUG"]!
    }
}
