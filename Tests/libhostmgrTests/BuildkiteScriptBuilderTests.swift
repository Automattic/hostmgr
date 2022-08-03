import Foundation
import XCTest
@testable import libhostmgr
import DotEnv

class BuildkiteScriptBuilderTests: XCTestCase {

    private var codeQuoteEnvironmentPath: String {
        getPathForEnvFile(named: "buildkite-environment-variables-with-code-quotes")
    }

    private var basicEnvironmentPath: String { getPathForEnvFile(named: "buildkite-environment-variables-basic") }

    private var scriptBuilder: BuildkiteScriptBuilder!

    override func setUpWithError() throws {
        self.scriptBuilder = BuildkiteScriptBuilder()
    }

    override func tearDownWithError() throws {
        self.scriptBuilder = nil
    }

    // MARK: - Dependency Tests
    func testThatBuildScriptContainsDependency() throws {
        scriptBuilder.addDependency(atPath: "~/.bashrc")
        XCTAssertTrue(scriptBuilder.build().contains("source ~/.bashrc"))
    }

    func testThatBuildScriptEscapesDependencyPath() throws {
        let result = scriptBuilder.convertDependencyToSource("/Users/my builder user/.bashrc")
        XCTAssertEqual("source /Users/my\\ builder\\ user/.bashrc", result)
    }

    // MARK: - Environment Variable Tests
    func testThatOrganizationSlugEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(
            BuildkiteScriptBuilder.Value(wrapping: "automattic"),
            scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"]
        )
        XCTAssertEqual(
            "automattic",
            scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"]?.escapedRepresentation
        )
    }

    func testThatCommitMessageEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(
            BuildkiteScriptBuilder.Value(wrapping: "A simple message with `code quotes`"),
            scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"]
        )
        XCTAssertEqual(
            "A simple message with \\`code quotes\\`",
            scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"]?.escapedRepresentation
        )
    }

    func testThatPullRequestEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(
            BuildkiteScriptBuilder.Value(wrapping: "19136"),
            scriptBuilder.environmentVariables["BUILDKITE_PULL_REQUEST"]
        )
    }

    func testThatCommitMessageWithCodeQuotesIsProperlyEscaped() throws {
        let original = try getContentsOfResourceAsValue(
            named: "buildkite-commit-message-original",
            withExtension: "txt"
        )

        XCTAssertEqual(
            try getContentsOfResource(named: "buildkite-commit-message-expected", withExtension: "txt"),
            original.escapedRepresentation
        )
    }

    // MARK: - Command Tests
    func testThatCommandDoesNotQuoteCompoundCommands() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent", arguments: ["bootstrap"])
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandEscapingDoesNotQuoteMultiWordCommands() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent bootstrap")
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandQuotesArgumentsContainingSpaces() throws {
        let command = BuildkiteScriptBuilder.Command(
            command: "buildkite-agent bootstrap",
            arguments: ["/Users/my builder user/.bashrc"]
        )

        XCTAssertEqual(#"buildkite-agent bootstrap "/Users/my builder user/.bashrc""#, command.escapedText)
    }

    // MARK: End-to-end Tests

    // A test to ensure that output is the same as the previous version
    func testThatBasicCommandOutputMatchesExpectations() throws {
        let env = try DotEnv.read(path: basicEnvironmentPath)
        scriptBuilder.addDependency(atPath: "~/.circ")
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        scriptBuilder.addCommand("buildkite-agent", "bootstrap")
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE_AGENT_NAME", value: "builder")
        scriptBuilder.addEnvironmentVariable(
            named: "BUILDKITE_BUILD_PATH",
            value: "/usr/local/var/buildkite-agent/builds"
        )
        scriptBuilder.addEnvironmentVariable(named: "CI", value: "true")

        let expectedOutput = try getContentsOfResource(
            named: "buildkite-environment-variables-basic-expected-output",
            withExtension: "txt"
        )
        XCTAssertEqual(expectedOutput, scriptBuilder.build())
    }

    // MARK: - Test Helpers
    private func readLines(from env: DotEnv) -> [String: String] {
        env.lines.reduce(into: [:]) { partialResult, line in
            partialResult[line.key] = line.value
        }
    }

    private func getContentsOfResourceAsValue(
        named key: String,
        withExtension extension: String
    ) throws -> BuildkiteScriptBuilder.Value {
        try BuildkiteScriptBuilder.Value(wrapping: getContentsOfResource(named: key, withExtension: `extension`))
    }

    private func getContentsOfResource(named key: String, withExtension extension: String) throws -> String {
        let path = try XCTUnwrap(Bundle.module.path(forResource: key, ofType: `extension`))
        return try XCTUnwrap(String(contentsOfFile: path)).trimmingWhitespace
    }

    private func getPathForEnvFile(named key: String) -> String {
        Bundle.module.path(forResource: key, ofType: "env")!
    }
}
