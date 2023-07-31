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

    public static func elapsedTime(
        between start: Date,
        and end: Date,
        context: Formatter.Context = .standalone
    ) -> String {
        let formatter = DateComponentsFormatter()
        formatter.formattingContext = context
        formatter.includesApproximationPhrase = false
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.second, .minute, .hour]
        return formatter.string(from: start, to: end)!
    }

    public static func remainingTime(until date: Date, context: Formatter.Context = .standalone) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = context
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    public static func timeRemaining(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.includesApproximationPhrase = true
        formatter.includesTimeRemainingPhrase = true
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = [.second, .minute, .hour, .day, .month, .year]
        return formatter.string(from: Date(), to: Date() + interval) ?? "Calculating time remaining"
    }

    public static func timeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.includesApproximationPhrase = false
        formatter.includesTimeRemainingPhrase = false
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = [.second, .minute, .hour, .day, .month, .year]
        return formatter.string(from: Date(), to: Date() + interval) ?? "a while"
    }

    public static func percentage(_ number: Decimal) -> String {
        return percentage(NSDecimalNumber(decimal: number))
    }

    public static func percentage(_ number: Double) -> String {
        return percentage(NSNumber(value: number))
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
