import Foundation
import XCTest
@testable import libhostmgr
import DotEnv

class BuildkiteScriptBuilderTests: XCTestCase {

    private var codeQuoteEnvironmentPath: String { getPathForEnvFile(named: "buildkite-environment-variables-with-code-quotes") }
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
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"], BuildkiteScriptBuilder.Value(wrapping: "automattic"))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"]?.escapedRepresentation, "automattic")
    }

    func testThatCommitMessageEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"], BuildkiteScriptBuilder.Value(wrapping: "A simple message with `code quotes`"))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"]?.escapedRepresentation, "A simple message with \\`code quotes\\`")
    }

    func testThatPullRequestEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_PULL_REQUEST"], BuildkiteScriptBuilder.Value(wrapping: "19136"))
    }

    func testThatCommitMessageWithCodeQuotesIsProperlyEscaped() throws {
        let original = try getContentsOfResourceAsValue(named: "buildkite-commit-message-original", withExtension: "txt")
        let expected = try getContentsOfResource(named: "buildkite-commit-message-expected", withExtension: "txt")

        XCTAssertEqual(expected, original.escapedRepresentation)
    }

    // MARK: - Command Tests
    func testThatCommandEscapingDoesNotEscapeMultiWordCommands() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent bootstrap")
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandDoesNotEscapeCompoundCommands() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent", arguments: ["bootstrap"])
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandEscapesSpacesInArguments() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent bootstrap", arguments: ["/Users/my builder user/.bashrc"])
        XCTAssertEqual("buildkite-agent bootstrap \"/Users/my\\ builder\\ user/.bashrc\"", command.escapedText) // Note: this also tests that escaped strings are wrapped in quotes
    }

    // MARK: End-to-end Tests

    // A test to ensure that output is the same as the previous version
    func testThatBasicCommandOutputMatchesExpectations() throws {
        let env = try DotEnv.read(path: basicEnvironmentPath)
        scriptBuilder.addDependency(atPath: "~/.circ")
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        scriptBuilder.addCommand("buildkite-agent", "bootstrap")
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE_AGENT_NAME", value: "builder")
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE_BUILD_PATH", value: "/usr/local/var/buildkite-agent/builds")
        scriptBuilder.addEnvironmentVariable(named: "CI", value: "true")

        let expectedOutput = try getContentsOfResource(named: "buildkite-environment-variables-basic-expected-output", withExtension: "txt")
        XCTAssertEqual(expectedOutput, scriptBuilder.build())
    }

    // MARK: - Test Helpers
    private func readLines(from env: DotEnv) -> [String: String] {
        env.lines.reduce(into: [:]) { partialResult, line in
            partialResult[line.key] = line.value
        }
    }

    private func getContentsOfResourceAsValue(named key: String, withExtension extension: String) throws -> BuildkiteScriptBuilder.Value {
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
