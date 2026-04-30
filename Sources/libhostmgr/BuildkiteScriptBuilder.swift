import Foundation

public struct BuildkiteScriptBuilder {

    /// A list of files to run `source` against prior to executing the rest of the script.
    var dependencies = [String]()

    /// A list of key/value pairs representing environment variables that should be defined at the start of the script.
    var environmentVariables: [String: Value] = [:]

    /// A list of commands to run in the script.
    var commands = [Command]()

    public init() {}

    /// Add another dependency to the build script.
    ///
    /// Each dependency will be placed in a `source $DEPENDENCY` block at the top of the emitted build script
    public mutating func addDependency(atPath path: String) {
        self.dependencies.append(path)
    }

    /// Add an environment variable pair to the build script.
    ///
    /// If there's an existing environment variable with the same name, it will be overwritten.
    public mutating func addEnvironmentVariable(named key: String, value: String) {
        self.environmentVariables[key] = Value(wrapping: value)
    }

    /// Add a PATH-like environment variable that prepends paths to an existing shell variable.
    ///
    /// This is intentionally narrower than accepting a raw shell expression: each
    /// path is shell-escaped, and only the final existing variable reference is
    /// emitted as shell syntax. Path components must be non-empty and cannot
    /// contain `:`, because PATH-like shell variables use `:` as their separator.
    public mutating func addPathEnvironmentVariable(
        named key: String,
        prepending paths: [String],
        existingVariableName: String
    ) {
        precondition(Self.isValidEnvironmentVariableName(key), "Invalid environment variable name: \(key)")
        precondition(
            Self.isValidEnvironmentVariableName(existingVariableName),
            "Invalid existing environment variable name: \(existingVariableName)"
        )
        precondition(!paths.isEmpty, "PATH must have at least one component")
        precondition(
            paths.allSatisfy { !$0.isEmpty && !$0.contains(":") },
            "PATH components must be non-empty and cannot contain ':'"
        )
        self.environmentVariables[key] = Value(pathPrepending: paths, existingVariableName: existingVariableName)
    }

    /// Removes an environment variable pair from the build script.
    public mutating func removeEnvironmentVariable(named key: String) {
        self.environmentVariables.removeValue(forKey: key)
    }

    public mutating func removingEnvironmentVariable(named key: String) -> Self {
        self.removeEnvironmentVariable(named: key)
        return self
    }

    /// Copy environment variables from the existing environment into the build script based on their prefix.
    public mutating func copyEnvironmentVariables(
        prefixedBy prefix: String,
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        for (key, value) in environment where key.starts(with: prefix) {
            environmentVariables[key] = Value(wrapping: value)
        }
    }

    /// Add a line to the build script.
    ///
    /// This typically takes the form of a single command (like `cp foo bar`).
    public mutating func addCommand(_ command: String, _ arguments: String...) {
        self.commands.append(Command(command: command, arguments: arguments))
    }

    /// Compile the build script into a single string
    public func build() -> String {
        return [
            dependencies
                .map(convertDependencyToSource)
                .joined(separator: "\n"),
            environmentVariables
                .sorted { $0.0 < $1.0 }
                .filter { !$0.value.rawValue.isEmpty }
                .map(convertEnvironmentVariableToExport)
                .joined(separator: "\n"),
            commands
                .map(escapeCommand)
                .joined(separator: "\n"),
            "" // Enforce newline at EOF
        ].joined(separator: "\n")
    }

    /// Helper that takes a path like `~/.bashrc` and make it into a bash `source` command.
    ///
    /// Escapes spaces in paths automatically.
    ///
    /// Example:
    ///
    /// ```
    /// # Given a path of `~/.bashrc`:
    /// source ~/.bashrc
    /// ```
    func convertDependencyToSource(_ path: String) -> String {
        "source \(path.escapingSpaces)".trimmingWhitespace
    }

    /// Helper that takes an environment variable key/value pair to an `export` statement.
    ///
    /// Renders literal values via `Value.shellQuoted`, which delegates to
    /// `spm_shellEscaped()`. Values containing only allowlisted characters
    /// (alphanumerics plus `-_/:@%+=.,`) are emitted unquoted; anything else
    /// is wrapped in single quotes on Unix (with `'\''` for embedded single
    /// quotes) or double quotes on Windows. Either form disables shell
    /// expansion of the value, which is the property we rely on to safely
    /// pass attacker-controlled data such as `BUILDKITE_MESSAGE` through to
    /// the remote shell.
    ///
    /// PATH-like values are emitted by shell-escaping each path component and
    /// conditionally appending a validated existing variable reference such as
    /// `${PATH:+:$PATH}`.
    ///
    /// Examples:
    ///
    /// ```
    /// # Given foo=bar       (allowlist-clean — emitted unquoted)
    /// export foo=bar
    ///
    /// # Given foo=hello world
    /// export foo='hello world'
    /// ```
    func convertEnvironmentVariableToExport(_ pair: (String, Value)) -> String {
        return "export \(pair.0)=\(pair.1.shellRepresentation)".trimmingWhitespace
    }

    /// Helper that wraps command escape logic for shorthand use in a `map` statement.
    func escapeCommand(_ command: Command) -> String {
        command.escapedText
    }

    /// An object representing the `value` in an environment variable's key/value pair.
    ///
    /// Mostly just a way to organize escaping
    struct Value: Equatable {
        private let representation: ValueRepresentation

        var rawValue: String {
            switch representation {
            case .literal(let value):
                value
            case .pathPrepending(let paths, let existingVariableName):
                paths.joined(separator: ":") + "${\(existingVariableName):+:$\(existingVariableName)}"
            }
        }

        init(wrapping: String) {
            self.representation = .literal(wrapping)
        }

        init(pathPrepending paths: [String], existingVariableName: String) {
            self.representation = .pathPrepending(paths, existingVariableName: existingVariableName)
        }

        /// The value formatted for safe placement in a shell script as a quoted token.
        ///
        /// Delegates to `spm_shellEscaped()`, which uses single-quote wrapping (with
        /// `'\''` escaping for embedded single quotes). Single-quoted strings perform
        /// no expansion in POSIX shells, so the resulting token is safe even when the
        /// value contains backticks, dollar signs, backslashes, or other shell
        /// metacharacters. Values that contain only allowlisted characters are
        /// returned unquoted.
        var shellQuoted: String {
            rawValue.spm_shellEscaped()
        }

        /// The value formatted for placement after `KEY=` in an export statement.
        var shellRepresentation: String {
            switch representation {
            case .literal:
                shellQuoted
            case .pathPrepending(let paths, let existingVariableName):
                paths.map { $0.spm_shellEscaped() }.joined(separator: ":")
                    + "${\(existingVariableName):+:$\(existingVariableName)}"
            }
        }
    }

    private enum ValueRepresentation: Equatable {
        case literal(String)
        case pathPrepending([String], existingVariableName: String)
    }

    /// An object representing one command in a shell script
    struct Command {
        /// The underlying command. If you want to handle escaping yourself, put the entire command here.
        let command: String

        /// The arguments for the command.
        let arguments: [String]

        init(command: String, arguments: [String] = []) {
            self.command = command
            self.arguments = arguments
        }

        /// The escaped command text, sutible for placement in a shell script
        var escapedText: String {
            "\(command) \(escapedArguments.joined(separator: " "))".trimmingWhitespace
        }

        /// A helper to print only the escaped arguments
        var escapedArguments: [String] {
            arguments.map { $0.spm_shellEscaped() }
        }
    }
}

extension String {
    var escapingSpaces: String {
        replacingOccurrences(of: " ", with: "\\ ")
    }
}

private extension BuildkiteScriptBuilder {
    static func isValidEnvironmentVariableName(_ name: String) -> Bool {
        guard let first = name.utf8.first else {
            return false
        }

        let validFirstCharacter = first == UInt8(ascii: "_")
            || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(first)
            || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(first)
        guard validFirstCharacter else {
            return false
        }

        return name.utf8.dropFirst().allSatisfy {
            $0 == UInt8(ascii: "_")
                || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains($0)
                || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains($0)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
        }
    }
}
