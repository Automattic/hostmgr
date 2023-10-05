import Foundation

public struct VMUsageRecord {
    public let vm: String
    public let date: Date

    public func isAfter(date: Date) -> Bool {
        self.date.timeIntervalSince1970 > date.timeIntervalSince1970
    }
}

public struct VMUsageAggregate {
    public let vm: String
    public let count: Int
    public let lastUsed: Date

    public func merging(_ records: [VMUsageRecord]) -> VMUsageAggregate {
        records.reduce(self) { $0.merging($1) }
    }

    public func merging(_ record: VMUsageRecord) -> VMUsageAggregate {
        let count = self.count + 1
        let date = record.isAfter(date: lastUsed) ? record.date : lastUsed
        return VMUsageAggregate(vm: vm, count: count, lastUsed: date)
    }

    public static func from(record: VMUsageRecord) -> VMUsageAggregate {
        VMUsageAggregate(vm: record.vm, count: 1, lastUsed: record.date)
    }

    public static func from(_ records: [VMUsageRecord]) -> VMUsageAggregate? {
        var mutableRecords = records

        guard let initialrecord = mutableRecords.popLast() else {
            return nil
        }

        return VMUsageAggregate.from(record: initialrecord).merging(mutableRecords)
    }
}

extension [VMUsageRecord] {
    public func grouped() -> [VMUsageAggregate] {
        var aggregatedRecords = [String: VMUsageAggregate]()

        for record in self {
            if let existingRecord = aggregatedRecords[record.vm] {
                aggregatedRecords[record.vm] = existingRecord.merging(record)
            } else {
                aggregatedRecords[record.vm] = VMUsageAggregate.from(record: record)
            }
        }

        return aggregatedRecords.values.map { $0 }
    }

}

extension [VMUsageAggregate] {
    public func asTable() -> Console.Table {
        self.map { [$0.vm, String($0.count)] }
    }

    func unused(since: Date) -> Self {
        self.filter {
            $0.lastUsed.timeIntervalSince1970 < since.timeIntervalSince1970
        }
    }
}
