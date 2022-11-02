import Foundation

public struct Format {

    public static func fileBytes(_ count: Double) -> String {
        // Don't continue unless the rate can be represented by `Int64`
        guard count.isNormal else {
            return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
        }

        return ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    public static func fileBytes(_ count: Int) -> String {
        fileBytes(Int64(count))
    }

    public static func fileBytes(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.zeroPadsFractionDigits = true
        formatter.countStyle = .file
        return formatter.string(fromByteCount: count)
    }

    public static func memoryBytes(_ count: UInt64) -> String {
        memoryBytes(Int64(count))
    }

    public static func memoryBytes(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.zeroPadsFractionDigits = true
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: count)
    }

    public static func time(_ interval: TimeInterval) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .standalone
        return formatter.localizedString(fromTimeInterval: interval)
    }

    public static func percentage(_ number: Decimal) -> String {
        return percentage(NSDecimalNumber(decimal: number))
    }

    public static func percentage(_ number: NSNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.roundingMode = .down
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(for: number)!
    }
}
