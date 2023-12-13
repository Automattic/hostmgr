import Foundation
import Crypto

struct HMAC256 {
    static func sign(data: Data, key: Data) -> String {
        return sign(data: data, key: key).hexEncodedString()
    }

    static func sign(data: Data, key: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let code = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return code.reduce(into: Data()) { $0.append($1) }
    }

    static func sign(string: String, key: Data) -> Data {
        sign(data: Data(string.utf8), key: key)
    }

    static func sign(string: String, key: String) -> Data {
        sign(string: string, key: Data(key.utf8))
    }
}
