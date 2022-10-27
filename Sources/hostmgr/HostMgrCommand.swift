import ArgumentParser
import Logging
import libhostmgr

@main
struct Hostmgr: AsyncParsableCommand {

    private static var appVersion = "0.15.0-beta.4"

    static var configuration = CommandConfiguration(
        abstract: "A utility for managing VM hosts",
        version: appVersion,
        subcommands: [
            VMCommand.self,
            SyncCommand.self,
            InitCommand.self,
            RunCommand.self,
            SetCommand.self,
            BenchmarkCommand.self,
            ConfigCommand.self
        ]
    )

    mutating func run() async throws {
        Logger.initializeLoggingSystem()
        Logger.shared.trace("Starting Up")

        guard Configuration.isValid else {
            print("Invalid configuration – exiting")
            throw ExitCode(1)
        }

        throw CleanExit.helpRequest(self)
    }
}

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set system values",
        subcommands: [
            SetAutomaticLoginPasswordCommand.self
        ]
    )
}

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a configuration file"
    )

    func run() throws {
        if ConfigurationRepository.configurationFileExists {
            if !confirm("A configuration file already exists – would you like to continue?") {
                return
            }
        }

        print("== VM Image Storage ==\n")

        Configuration.shared.vmImagesBucket = prompt(
            "Which S3 bucket contains your VM images?",
            currentValue: Configuration.shared.vmImagesBucket
        )

        Configuration.shared.vmImagesRegion = prompt(
            "Which AWS region contains the \(Configuration.shared.vmImagesBucket) bucket?",
            currentValue: Configuration.shared.vmImagesRegion
        )

        print("== Authorized Keys Sync ==\n")

        Configuration.shared.authorizedKeysBucket = prompt(
            "Which S3 bucket contains your authorized_keys file?",
            currentValue: Configuration.shared.authorizedKeysBucket
        )

        Configuration.shared.authorizedKeysRegion = prompt(
            "Which AWS region contains the \(Configuration.shared.authorizedKeysBucket) bucket?",
            currentValue: Configuration.shared.authorizedKeysRegion
        )

        Configuration.shared.gitMirrorBucket = prompt(
            "Which S3 bucket would you like to use as the data source for the git mirror server?",
            currentValue: Configuration.shared.gitMirrorBucket
        )

        try Configuration.shared.save()

        print("Configuration Complete")
    }

    private func confirm(_ message: String) -> Bool {
        repeat {
            print(message + " (Y/N)")
            if let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if response.uppercased() == "Y" {
                    return true
                } else if response.uppercased() == "N" {
                    return false
                }
            }

        } while true
    }

    typealias ValidationCallback = (String) -> Bool

    private func promptForUInt(_ message: String, currentValue: UInt) -> UInt {
        let value = prompt(message, currentValue: "\(currentValue)") { value in
            UInt(value) != nil
        }

        return UInt(value)!
    }

    private func prompt(_ message: String, currentValue: String?, isValid: ValidationCallback? = nil) -> String {

        repeat {
            if let currentValue = currentValue, !currentValue.isEmpty {
                print(message + "[" + currentValue + "]:")
            } else {
                print(message + ":")
            }

            if let value = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {

                if let isValid = isValid {
                    if isValid(value) {
                        return value
                    } else {
                        if let currentValue = currentValue, isValid(currentValue) {
                            return currentValue
                        } else {
                            continue
                        }
                    }
                }

                if !value.isEmpty {
                    return value
                }

                if value.isEmpty, let currentValue = currentValue, !currentValue.isEmpty {
                    return currentValue
                }
            }

        } while true
    }
}
