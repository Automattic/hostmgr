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
    /// Automatically quote-wraps the value and escapes quotes as needed.
    ///
    /// Example:
    ///
    /// ```
    /// # Given `foo:bar`
    /// export foo="bar"
    /// ```
    func convertEnvironmentVariableToExport(_ pair: (String, Value)) -> String {
        return "export \(pair.0)=\"\(pair.1.escapedRepresentation)\"".trimmingWhitespace
    }

    /// Helper that wraps command escape logic for shorthand use in a `map` statement.
    func escapeCommand(_ command: Command) -> String {
        command.escapedText
    }

    /// An object representing the `value` in an environment variable's key/value pair.
    ///
    /// Mostly just a way to organize escaping
    struct Value: Equatable {
        let rawValue: String

        init(wrapping: String) {
            self.rawValue = wrapping
        }

        /// An version of this value suitable for placement in a shell script
        var escapedRepresentation: String {
            rawValue
                .escapingCodeQuotes
                .escapingDoubleQuotes
        }
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

    var escapingCodeQuotes: String {
        replacingOccurrences(of: "`", with: "\\`")
    }

    var escapingDoubleQuotes: String {
        replacingOccurrences(of: "\"", with: "\\\"")
    }
}
