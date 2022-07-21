import Foundation
import ArgumentParser
import Logging

struct GeneratePasswordCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "password",
        abstract: "Generate a git mirror server manifest"
    )

    @Option(
        name: .shortAndLong,
        help: "The length of the generated password"
    )
    var length: Int = 64

    func run() throws {
        print(randomString(length: length))
    }

    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
