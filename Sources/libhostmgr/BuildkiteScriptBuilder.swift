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

    /// Copy environment variables from the existing environment into the build script based on their prefix.
    public mutating func copyEnvironmentVariables(prefixedBy prefix: String, from environment: [String: String] = ProcessInfo.processInfo.environment) {
        environment
            .filter { $0.key.starts(with: prefix) }
            .forEach { key, value in
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
            dependencies.map(convertDependencyToSource).joined(separator: "\n"),
            environmentVariables.map(convertEnvironmentVariableToExport).joined(separator: "\n"),
            commands.map(escapeCommand).joined(separator: "\n")
        ].joined(separator: "\n")
    }

    func convertDependencyToSource(_ path: String) -> String {
        "source \(path.escapingSpaces)"
    }

    func convertEnvironmentVariableToExport(_ pair: (String, Value)) -> String {
        return "export \(pair.0)=\(pair.1)"
    }

    func escapeCommand(_ command: Command) -> String {
        command.escapedText
    }

    struct Value: Equatable {

        let rawValue: String

        init(wrapping: String) {
            self.rawValue = wrapping
        }

        var encodedRepresentation: String {
            rawValue
                .escapingCodeQuotes
                .escapingDoubleQuotes
        }
    }

    struct Command {
        let command: String
        let arguments: [String]

        init(command: String, arguments: [String] = []) {
            self.command = command
            self.arguments = arguments
        }

        var escapedText: String {
            "\(command) \(escapedArguments.joined(separator: " "))"
        }

        var escapedArguments: [String] {
            arguments.map { $0.escapingSpaces }
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
