

//import Foundation
//import Virtualization
//
//struct MACAddress {
//
//    static let prefix = (0x06 as u_char, 0xa8 as u_char, 0xc0 as u_char)
//
//    let rawValue: ether_addr_t
//
//    private init(rawValue: ether_addr_t) {
//        self.rawValue = rawValue
//    }
//
//    init(_ _0: u_char, _ _1: u_char, _ _2: u_char, _ _3: u_char, _ _4: u_char, _ _5: u_char) {
//        self.rawValue = ether_addr_t(octet: (_0, _1, _2, _3, _4, _5))
//    }
//
//    init?(_ string: String) {
//        let data = string.split(separator: ":").compactMap { UInt8($0, radix: 16) }
//
//        guard data.count == 6 else {
//            return nil
//        }
//
//        self.rawValue = ether_addr_t(octet: (data[0], data[1], data[2], data[3], data[4], data[5]))
//    }
//
//    static func rawAddress(firstByte: u_char, secondByte: u_char, thirdByte: u_char) -> ether_addr_t {
//        ether_addr_t(octet: (prefix.0, prefix.1, prefix.2, firstByte, secondByte, thirdByte))
//    }
//
//    static func random() -> Self {
//        VZMACAddress.randomLocallyAdministered()
//        MACAddress(rawValue: rawAddress(
//            firstByte: UInt8.random(in: 0...UInt8.max),
//            secondByte: UInt8.random(in: 0...UInt8.max),
//            thirdByte: UInt8.random(in: 0...UInt8.max)
//        ))
//    }
//
//    static func derive(fromVirtualMachine bundle: VMBundle) -> Self? {
//        let hash = Data(bundle.name.utf8).sha256
//        return MACAddress(rawValue: rawAddress(
//            firstByte: hash[hash.count - 1 ],
//            secondByte: hash[hash.count - 2],
//            thirdByte: hash[hash.count - 3]
//        ))
//    }
//
//    var stringValue: String {
//        [rawValue.octet.0, rawValue.octet.1, rawValue.octet.2, rawValue.octet.3, rawValue.octet.4, rawValue.octet.5]
//            .map { String(format: "%02hhx", $0) }
//            .joined(separator: ":")
//    }
//}
//
//extension MACAddress: Codable {
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(stringValue)
//    }
//
//    init(from decoder: Decoder) throws {
//        let stringValue = try decoder.singleValueContainer().decode(String.self)
//
//        guard let newSelf = MACAddress(stringValue) else {
//            throw CocoaError(.coderInvalidValue)
//        }
//
//        self = newSelf
//    }
//}
//
//extension MACAddress: Equatable {
//    static func == (lhs: MACAddress, rhs: MACAddress) -> Bool {
//        lhs.rawValue.octet == rhs.rawValue.octet
//    }
//}
