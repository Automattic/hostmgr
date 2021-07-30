import ArgumentParser
import SotoS3
import Logging

struct HostMgr: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "A utility for managing VM hosts",
        subcommands: [
            VMCommand.self,
            SyncCommand.self,
            InitCommand.self,
            RunCommand.self,
            SetCommand.self,
        ])

    @Flag(help: "Print the version and exit")
    var version: Bool = false

    func run() throws {
        logger.debug("Starting Up")
        if version {
            print("1.0.0")
        } else {
            throw CleanExit.helpRequest(self)
        }
    }
}

initializeLoggingSystem()
HostMgr.main()

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set system values",
        subcommands: [
            SetAutomaticLoginPasswordCommand.self,
        ]
    )
}

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a configuration file"
    )

    func run() throws {
        if StateManager.configurationFileExists {
            if !confirm("A configuration file already exists – would you like to continue?") {
                return
            }
        }

        print("== VM Image Storage ==\n")

        Configuration.shared.vmImagesBucket = prompt(
            "Which S3 bucket contains your VM images?",
            currentValue: Configuration.shared.vmImagesBucket
        )

        let vmImagesRegion = prompt(
            "Which AWS region contains the \(Configuration.shared.vmImagesBucket) bucket?",
            currentValue: Configuration.shared.vmImagesRegion.rawValue
        ) { Region(awsRegionName: $0) != nil }

        Configuration.shared.vmImagesRegion = Region(awsRegionName: vmImagesRegion)!

        print("== Authorized Keys Sync ==\n")

        let authorizedKeysSyncInterval = prompt(
            "How frequently would you like to sync the authorized_keys file? (in seconds)",
            currentValue: String(Configuration.shared.authorizedKeysSyncInterval)
        ) { Int($0) != nil && Int($0) != 0 }

        Configuration.shared.authorizedKeysSyncInterval = Int(authorizedKeysSyncInterval)!

        Configuration.shared.authorizedKeysBucket = prompt(
            "Which S3 bucket contains your authorized_keys file?",
            currentValue: Configuration.shared.authorizedKeysBucket
        )

        let authorizedKeysRegion = prompt(
            "Which AWS region contains the \(Configuration.shared.authorizedKeysBucket) bucket?",
            currentValue: Configuration.shared.authorizedKeysRegion.rawValue
        ) { Region(awsRegionName: $0) != nil }

        Configuration.shared.authorizedKeysRegion = Region(awsRegionName: authorizedKeysRegion)!

        print("== Git Mirror Server Setup ==\n")
        Configuration.shared.gitMirrorPort = promptForUInt(
            "Which port would you like to use for the git mirror server?",
            currentValue: Configuration.shared.gitMirrorPort
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
                    }
                    else {
                        if let currentValue = currentValue, isValid(currentValue) {
                            return currentValue
                        }
                        else {
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
