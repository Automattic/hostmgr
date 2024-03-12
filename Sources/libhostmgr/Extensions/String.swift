import Foundation

extension String {
    public var trimmingWhitespace: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // In a Terminal, emoji characters take near to twice the width as regular characters
    // This thus accounts for that difference, to reflect the number of Terminal columns this string will span
    public var monospaceWidth: Int {
        self.count + self.unicodeScalars.filter(\.properties.isEmojiPresentation).count
    }
}

// MARK: TSCBasic Code

/// Copied out of the TSCBasic project, which has been deprecated and isn't recommended for use
/// Original from: https://github.com/apple/swift-tools-support-core/Sources/TSCBasic/StringConversions.swift
///
extension String {
    /// Creates a shell escaped string. If the string does not need escaping, returns the original string.
    /// Otherwise escapes using single quotes on Unix and double quotes on Windows. For example:
    /// hello -> hello, hello$world -> 'hello$world', input A -> 'input A'
    ///
    /// - Returns: Shell escaped string.
    public func spm_shellEscaped() -> String {

        // If all the characters in the string are in the allow list then no need to escape.
        guard let pos = utf8.firstIndex(where: { !inShellAllowlist($0) }) else {
            return self
        }

      #if os(Windows)
        let quoteCharacter: Character = "\""
        let escapedQuoteCharacter = "\"\""
      #else
        let quoteCharacter: Character = "'"
        let escapedQuoteCharacter = "'\\''"
      #endif
        // If there are no quote characters then we can just wrap the string within the quotes.
        guard let quotePos = utf8[pos...].firstIndex(of: quoteCharacter.asciiValue!) else {
            return String(quoteCharacter) + self + String(quoteCharacter)
        }

        // Otherwise iterate and escape all the single quotes.
        var newString = String(quoteCharacter) + String(self[..<quotePos])

        for char in self[quotePos...] {
            if char == quoteCharacter {
                newString += escapedQuoteCharacter
            } else {
                newString += String(char)
            }
        }

        newString += String(quoteCharacter)

        return newString
    }

    private func inShellAllowlist(_ codeUnit: UInt8) -> Bool {
      #if os(Windows)
        if codeUnit == UInt8(ascii: "\\") {
            return true
        }
      #endif
        switch codeUnit {
        case UInt8(ascii: "a")...UInt8(ascii: "z"),
            UInt8(ascii: "A")...UInt8(ascii: "Z"),
            UInt8(ascii: "0")...UInt8(ascii: "9"),
            UInt8(ascii: "-"),
            UInt8(ascii: "_"),
            UInt8(ascii: "/"),
            UInt8(ascii: ":"),
            UInt8(ascii: "@"),
            UInt8(ascii: "%"),
            UInt8(ascii: "+"),
            UInt8(ascii: "="),
            UInt8(ascii: "."),
            UInt8(ascii: ","):
            return true
        default:
            return false
        }
    }

}
