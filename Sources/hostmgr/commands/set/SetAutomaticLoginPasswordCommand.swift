import Foundation
import ArgumentParser
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

    private let path = URL(fileURLWithPath: "/etc/kcpassword")

    enum CodingKeys: CodingKey {
        case password
        case force
    }

    func run() throws {

        // Don't run if the file exists (unless the user specifies `--force`)
        guard !FileManager.default.fileExists(at: path) || force else {
            print("Not writing to \(path) – it already exists")
            return
        }

        if FileManager.default.fileExists(at: path) {
            try FileManager.default.removeItem(at: path)
        }

        let data = kcpassword(encrypting: password)
        try data.write(to: path, options: .atomicWrite)
        try FileManager.default.set(filePermissions: .ownerReadWrite, forItemAt: path)
    }
}
