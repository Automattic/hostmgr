import Foundation
import ConsoleKit
import tinys3

public struct Console {

    let terminal = Terminal()

    @discardableResult public func heading(_ message: String, underline: String = "=") -> Self {
        self.terminal.output(message, style: .plain)
        self.terminal.output(String.init(repeating: underline, count: message.count), style: .plain)
        return self
    }

    @discardableResult public func success(_ message: String) -> Self {
        self.terminal.success(message)
        return self
    }

    @discardableResult public func error(_ message: String) -> Self {
        self.terminal.error(message)
        return self
    }

    @discardableResult public func warn(_ message: String) -> Self {
        self.terminal.warning(message)
        return self
    }

    @discardableResult public func info(_ message: String) -> Self {
        self.terminal.info(message)
        return self
    }

    @discardableResult public func log(_ message: String) -> Self {
        self.terminal.print(message)
        return self
    }

    @discardableResult func message(_ message: String, style: ConsoleStyle) -> Self {
        self.terminal.output(message, style: style)
        return self
    }

    @discardableResult public func printList(_ list: [String], title: String) -> Self {
        self.terminal.print(title)

        guard !list.isEmpty else {
            self.terminal.print("  [Empty]")
            return self
        }

        for item in list {
            self.terminal.print("  " + item)
        }

        return self
    }

    @discardableResult public func printTable(
        data: Table,
        columnTitles: [String] = [],
        columnSeparator: String = "  "
    ) -> Self {

        if data.isEmpty {
            self.terminal.print("[Empty]")
            return self
        }

        // Prepend the Column Titles, if present
        let table = columnTitles.isEmpty ? data : [columnTitles] + data

        let columnCount = columnCounts(for: table)

        for row in table {
            let string = zip(row, columnCount).map(self.padString).joined(separator: columnSeparator)
            self.terminal.print(string)
        }

        return self
    }
}

public class ProgressBar {

    private let terminal = Terminal()
    private let startDate = Date()

    private var lastUpdateAt: Int = 0

    init(title: String) {
        terminal.info(title)
        terminal.print() // Deliberately empty string
    }

    public static func start(title: String) -> ProgressBar {
        return ProgressBar(title: title)
    }

    public func update(_ progress: Progress) {
        let progress = FileTransferProgress(
            completed: Int(progress.completedUnitCount),
            total: Int(progress.totalUnitCount),
            startDate: startDate
        )

        self.update(progress)
    }

    public func update(_ progress: FileTransferProgress) {

        // Only update progress once per second
        let now = Int(Date().timeIntervalSince1970)
        guard now > lastUpdateAt else {
            return
        }

        let rate = Format.fileBytes(progress.dataRate)
        let remaining = Format.time(progress.estimatedTimeRemaining)
        let percentage = Format.percentage(progress.fractionComplete)

        // Erase the old progress line and overwrite it
        terminal.clear(lines: 1)
        terminal.print("\(percentage) [\(rate)/s, \((remaining))]")

        // Make sure we don't update again this second
        self.lastUpdateAt = now
    }
}

// MARK: Static Helpers
extension Console {
    public static func startProgress(_ string: String) -> ProgressBar {
        ProgressBar(title: string)
    }

    public static func startImageDownload(_ image: RemoteVMImage) -> ProgressBar {
        let size = Format.fileBytes(image.imageObject.size)
        return ProgressBar(title: "Downloading \(image.fileName) (\(size))")
    }

    public static func startFileDownload(_ file: S3Object) -> ProgressBar {
        let size = Format.fileBytes(file.size)
        return ProgressBar(title: "Downloading \(file.key) (\(size))")
    }
}

// MARK: Static Initializers
extension Console {
    @discardableResult public static func heading(_ message: String) -> Self {
        return Console().heading(message)
    }

    @discardableResult public static func success(_ message: String) -> Self {
        return Console().success(message)
    }

    @discardableResult public static func error(_ message: String) -> Self {
        return Console().error(message)
    }

    @discardableResult public static func warn(_ message: String) -> Self {
        return Console().warn(message)
    }

    @discardableResult public static func info(_ message: String) -> Self {
        return Console().info(message)
    }

    @discardableResult public static func log(_ message: String) -> Self {
        return Console().log(message)
    }

    @discardableResult public static func printList(_ list: [String], title: String) -> Self {
        return Console().printList(list, title: title)
    }

    @discardableResult public static func printTable(data: Table, columnTitles: [String] = []) -> Self {
        return Console().printTable(data: data, columnTitles: columnTitles)
    }

    public static func crash(message: String, reason error: ExitCode) -> Never {
        Console().error(message)
        Foundation.exit(error.rawValue)
    }

    public static func exit(message: String = "", style: ConsoleStyle = .plain) -> Never {
        Console().message(message, style: style)
        Foundation.exit(0)
    }
}

// MARK: Table Support
extension Console {
    public typealias Table = [[String]]

    func columnCounts(for table: Table) -> [Int] {
        transpose(matrix: table).map { $0.map(\.count).max() ?? 0 }
    }

    func transpose(matrix: Table) -> Table {
        guard let numberOfColumns = matrix.first?.count else {
            return matrix
        }

        var newTable = [[String]](repeating: [String](repeating: "", count: matrix.count), count: numberOfColumns)

        for (rowIndex, row) in matrix.enumerated() {
            for (colIndex, col) in row.enumerated() {
                newTable[colIndex][rowIndex] = col
            }
        }

        return newTable
    }

    func padString(_ string: String, toLength length: Int) -> String {
        string.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}
