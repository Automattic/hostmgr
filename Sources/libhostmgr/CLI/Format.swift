import Foundation

public struct Format {

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
}
