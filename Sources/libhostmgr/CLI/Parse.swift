import Foundation

public struct Parse {

    static let caddyFullDatetime: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }()

    static func caddyDatetime(_ string: String, timezone: TimeZone = .gmt) -> Date? {
        caddyFullDatetime.timeZone = timezone
        return caddyFullDatetime.date(from: string)
    }

}
