import Foundation
import XCTest
@testable import libhostmgr
import DotEnv

class BuildkiteScriptBuilderTests: XCTestCase {

    private var codeQuoteEnvironmentPath: URL {
        getPathForEnvFile(named: "buildkite-environment-variables-with-code-quotes")
    }

    private var basicEnvironmentPath: URL {
        getPathForEnvFile(named: "buildkite-environment-variables-basic")
    }

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
        let variables = try getEnvironmentVariables(from: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: variables)
        XCTAssertEqual(
            BuildkiteScriptBuilder.Value(wrapping: "automattic"),
            scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"]
        )
        XCTAssertEqual(
            "automattic",
            scriptBuilder.environmentVariables["BUILDKITE_ORGANIZATION_SLUG"]?.shellQuoted
        )
    }

    func testThatCommitMessageEnvironmentVariableIsImported() throws {
        let variables = try getEnvironmentVariables(from: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: variables)
        XCTAssertEqual(
            BuildkiteScriptBuilder.Value(wrapping: "A simple message with `code quotes`"),
            scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"]
        )
        XCTAssertEqual(
            "'A simple message with `code quotes`'",
            scriptBuilder.environmentVariables["BUILDKITE_MESSAGE"]?.shellQuoted
        )
    }

    func testThatPullRequestEnvironmentVariableIsImported() throws {
        let variables = try getEnvironmentVariables(from: codeQuoteEnvironmentPath)
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: variables)
        XCTAssertEqual(
            BuildkiteScriptBuilder.Value(wrapping: "19136"),
            scriptBuilder.environmentVariables["BUILDKITE_PULL_REQUEST"]
        )
    }

    // MARK: - Shell-injection regression tests
    //
    // BUILDKITE_MESSAGE is attacker-controllable — its value is the head commit's
    // message, which any pull request author can set. The previous escaping
    // (escapingCodeQuotes + escapingDoubleQuotes inside double quotes) was unsafe
    // for messages containing a backslash followed by a backtick, because the
    // existing backslash got consumed by the new escape, leaving the backtick
    // active inside the double-quoted export and triggering command substitution
    // when the script ran.
    //
    // These tests assert that no shell expansion happens for the value, by
    // sourcing the generated export line in a real shell and reading the
    // variable back.

    func testThatExportRoundTripsValueContainingBackslashBacktick() throws {
        // The exact payload that triggered the original bug: backslash-backtick
        // pairs around tokens. With the unsafe escaping, sourcing this export
        // line in zsh or bash printed `command not found` and clobbered the
        // value with the substituted output.
        let payload = #"line with \`whoami\` and \`/etc/passwd\`"#
        try assertExportPreservesValue(payload)
    }

    func testThatExportRoundTripsValueContainingPlainBackticks() throws {
        try assertExportPreservesValue("plain `whoami` and `/etc/passwd`")
    }

    func testThatExportRoundTripsValueContainingDollarExpansion() throws {
        try assertExportPreservesValue(#"value $HOME and ${PATH} should not expand"#)
    }

    func testThatExportRoundTripsValueContainingSingleQuotes() throws {
        try assertExportPreservesValue("can't won't shouldn't")
    }

    func testThatExportRoundTripsValueContainingDoubleQuotes() throws {
        try assertExportPreservesValue(#"a "quoted" word"#)
    }

    func testThatExportRoundTripsMultiLineCommitMessage() throws {
        let payload = """
        Subject line

        Body with \\`escaped\\` and `plain` backticks,
        plus a $variable and "quotes".
        """
        try assertExportPreservesValue(payload)
    }

    // MARK: - Command Tests
    func testThatCommandDoesNotQuoteCompoundCommands() throws {
        let command = BuildkiteScriptBuilder.Command("buildkite-agent", "bootstrap")
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandEscapingDoesNotQuoteMultiWordCommands() throws {
        let command = BuildkiteScriptBuilder.Command("buildkite-agent bootstrap")
        XCTAssertEqual("buildkite-agent bootstrap", command.escapedText)
    }

    func testThatCommandQuotesArgumentsContainingSpaces() throws {
        let command = BuildkiteScriptBuilder.Command("buildkite-agent bootstrap", "/Users/my builder user/.bashrc")
        XCTAssertEqual(#"buildkite-agent bootstrap '/Users/my builder user/.bashrc'"#, command.escapedText)
    }

    func testThatCommandQuotesArgumentsContainingSingleQuotes() throws {
        let command = BuildkiteScriptBuilder.Command(
            "buildkite-agent bootstrap",
            "--name",
            "My 'very important' agent"
        )

        XCTAssertEqual(#"buildkite-agent bootstrap --name 'My '\''very important'\'' agent'"#, command.escapedText)
    }

    func testThatCommandQuotesArgumentsContainingDoubleQuotes() throws {
        let command = BuildkiteScriptBuilder.Command(
            "buildkite-agent bootstrap",
            "--name",
            #"My "very important" agent"#
        )

        XCTAssertEqual(#"buildkite-agent bootstrap --name 'My "very important" agent'"#, command.escapedText)
    }

    // MARK: End-to-end Tests

    // A test to ensure that output is the same as the previous version
    func testThatBasicCommandOutputMatchesExpectations() throws {
        let variables = try getEnvironmentVariables(from: basicEnvironmentPath)
        scriptBuilder.addDependency(atPath: "~/.circ")
        scriptBuilder.addEnvironmentVariable(named: "BUILDKITE", value: "true")
        scriptBuilder.copyEnvironmentVariables(prefixedBy: "BUILDKITE_", from: variables)
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
    private func getContentsOfResource(named key: String, withExtension extension: String) throws -> String {
        let path = try XCTUnwrap(Bundle.module.path(forResource: key, ofType: `extension`))
        return try XCTUnwrap(String(contentsOfFile: path))
    }

    private func getEnvironmentVariables(from path: URL) throws -> [String: String] {
        try DotEnv.read(path: path.path())
            .lines
            .reduce(into: [String: String]()) { $0[$1.key] = $1.value }
    }

    /// Asserts that the given value, when written into the script as an export
    /// line and sourced by a real POSIX shell, round-trips byte-for-byte — i.e.
    /// the shell performs no expansion, no command substitution, no backslash
    /// processing on it.
    ///
    /// The check runs the generated export line through `/bin/sh -c`, reads the
    /// variable back, and compares against the input. If shell expansion fires,
    /// the read-back value will differ (or the shell will print errors and the
    /// process may even fail).
    private func assertExportPreservesValue(
        _ value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var builder = BuildkiteScriptBuilder()
        builder.addEnvironmentVariable(named: "BUILDKITE_TEST_VALUE", value: value)
        let exportLine = builder.build()

        // Source the generated script and emit the variable verbatim, framed by
        // sentinels so we can extract it cleanly even if it contains newlines.
        let shellScript = """
        \(exportLine)
        printf '<<<%s>>>' "$BUILDKITE_TEST_VALUE"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", shellScript]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""

        XCTAssertEqual(
            process.terminationStatus, 0,
            "shell exited non-zero. stderr: \(stderrText)",
            file: file, line: line
        )
        XCTAssertTrue(
            stderrText.isEmpty,
            "shell wrote to stderr (suggests expansion fired): \(stderrText)",
            file: file, line: line
        )

        guard let start = stdoutText.range(of: "<<<"),
              let end = stdoutText.range(of: ">>>", options: .backwards) else {
            XCTFail(
                "could not extract sentinel-framed value from stdout: \(stdoutText)",
                file: file, line: line
            )
            return
        }
        let observed = String(stdoutText[start.upperBound..<end.lowerBound])
        XCTAssertEqual(
            observed, value,
            "value did not round-trip through the shell",
            file: file, line: line
        )
    }
}

extension BuildkiteScriptBuilder.Command {
    init(_ command: String, _ arguments: String...) {
        self.init(command: command, arguments: arguments)
    }
}
