import Foundation
import ArgumentParser
import SotoS3
import kcpassword

struct SetAutomaticLoginPasswordCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "autologin-password",
        abstract: "Set this machine's authorized_keys file"
    )

    @Argument(
        help: "The new password"
    )
    var password: String

    @Flag(
        help: "Overwrite the password file if it already exists"
    )
    var force: Bool = false

    var path: String {
        "/etc/kcpassword"
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    func run() throws {

        /// Don't run if the file exists (unless the user specifies `--force`
        guard !FileManager.default.fileExists(atPath: path) || force else {
            print("Not writing to \(path) – it already exists")
            return
        }

        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(at: url)
        }

        let data = kcpassword(encrypting: password)
        try data.write(to: url, options: .atomicWrite)
        try FileManager.default.setAttributes([
            .posixPermissions: 0o600
        ], ofItemAtPath: path)
    }
}
