import Foundation
import XCTest
@testable import libhostmgr
import DotEnv

class BuildkiteScriptBuilderTests: XCTestCase {

    private var codeQuoteEnvironmentPath: String { getPathForEnvFile(named: "buildkite-environment-variables-with-code-quotes") }

    private var scriptBuilder: BuildkiteScriptBuilder!

    override func setUpWithError() throws {
        self.scriptBuilder = BuildkiteScriptBuilder()
    }

    override func tearDownWithError() throws {
        self.scriptBuilder = nil
    }

    func testThatOrganizationSlugEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"], BuildkiteScriptBuilder.Value(wrapping: "automattic"))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"]?.encodedRepresentation, "automattic")
    }

    func testThatCommitMessageEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"], BuildkiteScriptBuilder.Value(wrapping: "A simple message with `code quotes`"))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"]?.encodedRepresentation, "A simple message with \\`code quotes\\`")
    }

    func testThatPullRequestEnvironmentVariableIsImported() throws {
        let env = try DotEnv.read(path: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: readLines(from: env))
        XCTAssertEqual(scriptBuilder.environmentVariables["BUILDKITE_PULL_REQUEST"], BuildkiteScriptBuilder.Value(wrapping: "19136"))
    }

    func testThatCommitMessageWithCodeQuotesIsProperlyEscaped() throws {
        let original = try getContentsOfResourceAsValue(named: "buildkite-commit-message-original", withExtension: "txt")
        let expected = try getContentsOfResource(named: "buildkite-commit-message-expected", withExtension: "txt")

        XCTAssertEqual(expected, original.encodedRepresentation)
    }

    func testThatBuildScriptContainsDependency() throws {
        scriptBuilder.addDependency(atPath: "~/.bashrc")
        XCTAssertTrue(scriptBuilder.build().contains("source ~/.bashrc"))
    }

    func testThatBuildScriptEscapesDependencyPath() throws {
        let result = scriptBuilder.convertDependencyToSource("/Users/my builder user/.bashrc")
        XCTAssertEqual("source /Users/my\\ builder\\ user/.bashrc", result)
    }

    // MARK: Command Tests
    func testThatCommandDoesNotEscapeMultiWordCommands() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent bootstrap")
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandEscapesSpacesInArguments() throws {
        let command = BuildkiteScriptBuilder.Command(command: "buildkite-agent bootstrap", arguments: ["/Users/my builder user/.bashrc"])
        XCTAssertEqual("buildkite-agent bootstrap /Users/my\\ builder\\ user/.bashrc", command.escapedText)
    }

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
        return try XCTUnwrap(String(contentsOfFile: path))
    }

    private func getPathForEnvFile(named key: String) -> String {
        Bundle.module.path(forResource: key, ofType: "env")!
    }
}
