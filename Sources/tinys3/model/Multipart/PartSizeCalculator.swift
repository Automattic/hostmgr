import Foundation

struct PartSizeCalculator {
    static func calculate(basedOn fileSize: Int) -> Int {
        max(min(fileSize, 5_000_000), min(4_900_000_000, fileSize / 50))
    }
}
