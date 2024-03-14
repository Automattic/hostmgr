import Foundation
import ConsoleKit
import tinys3
import OSLog

public protocol Consolable {
    @discardableResult
    func success(_ message: String) -> Self

    @discardableResult
    func error(_ message: String) -> Self

    @discardableResult
    func warn(_ message: String) -> Self

    @discardableResult
    func info(_ message: String) -> Self

    @discardableResult
    func log(_ message: String) -> Self
}

public struct Console: Consolable {

    static let shared = Console()

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
        titleRowSeparator: Character? = "-",
        columnSeparator: String = " | ",
        columnAlignments: [TableColumnAlignment] = []
    ) -> Self {

        if data.isEmpty {
            self.terminal.print("[Empty]")
            return self
        }

        // Prepend the Column Titles, if present
        var table = columnTitles.isEmpty ? data : [columnTitles] + data

        let columnCount = columnCounts(for: table)

        if !columnTitles.isEmpty, let titleRowSeparator {
            let headerSeparatorRow = columnCount.map { String(repeating: titleRowSeparator, count: $0) }
            table.insert(headerSeparatorRow, at: 1)
        }

        for row in table {
            let string = zip(row, columnCount.indices).map { text, colIdx in
                let colWidth = columnCount[colIdx]
                let alignment: TableColumnAlignment = columnAlignments.indices ~= colIdx ? columnAlignments[colIdx] : .left
                return self.padString(text, toLength: colWidth, align: alignment)
            }.joined(separator: columnSeparator)
            self.terminal.print(string)
        }

        return self
    }

    @discardableResult public func startIndeterminateProgress(_ title: String) -> ActivityIndicator<CustomActivity> {
        let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"].map { $0 + " " + title }
        let bar = self.terminal.customActivity(frames: frames)
        bar.start(refreshRate: 80)
        return bar
    }
}

public class ProgressBar {

    private let terminal = Terminal()
    private let startDate = Date()

    private var lastUpdateAt: Int = 0
    private var currentRate: String?

    private let title: String
    private let type: ProgressType

    public enum ProgressType {
        case download
        case upload
        case installation
    }

    init(title: String, type: ProgressType, initialProgress: Progress) {
        self.title = title
        self.type = type

        terminal.info(title)

        self.update(initialProgress)
    }

    public func update(_ progress: Progress) {
        switch self.type {
        case .download, .upload: self.updateFileTransferProgress(progress)
        case .installation: self.updateInstallationProgress(progress)
        }
    }

    public func updateFileTransferProgress(_ progress: Progress) {
        // Only update progress once per second
        let now = Int(Date().timeIntervalSince1970)
        guard now > lastUpdateAt else {
            return
        }

        let progress = FileTransferProgress(
            completed: Int(progress.completedUnitCount),
            total: Int(progress.totalUnitCount),
            startDate: startDate
        )

        let rate = Format.fileBytes(progress.dataRate)
        let remaining = Format.timeRemaining(progress.estimatedTimeRemaining)
        let percentage = Format.percentage(progress.fractionComplete)

        // Erase the old progress line and overwrite it
        if lastUpdateAt != 0 {
            terminal.clear(lines: 1)
        }

        terminal.print("\(percentage) [\(rate)/s, \((remaining))]")

        // Make sure we don't update again this second
        self.lastUpdateAt = now

        // Save the rate to display at the end
        self.currentRate = rate
    }

    public func updateInstallationProgress(_ progress: Progress) {
        // Only update progress once per second
        let now = Int(Date().timeIntervalSince1970)
        guard now > lastUpdateAt else {
            return
        }

        let percentage = Format.percentage(progress.fractionCompleted)

        // Erase the old progress line and overwrite it
        terminal.clear(lines: 1)

        if let remaining = progress.estimatedTimeRemaining {
            terminal.info("\(title) \(percentage) [\((remaining))]")
        } else {
            terminal.info("\(title) \(percentage)")
        }

        // Make sure we don't update again this second
        self.lastUpdateAt = now
    }

    public func succeed() {
        let elapsedTime = Format.elapsedTime(between: startDate, and: .now, context: .middleOfSentence)

        switch type {
        case .installation:
            terminal.clear(lines: 1)
            terminal.success("Finished in \(elapsedTime)")
        case .download, .upload:
            terminal.clear(lines: 1)

            if let rate = self.currentRate {
                terminal.success("Finished in \(elapsedTime) (\(rate)/s)")
            } else {
                terminal.success("Finished in \(elapsedTime)")
            }
        }
    }
}

// MARK: Static Helpers
extension Console {

    public typealias ProgressUpdateCallback = (ProgressBar) async throws -> Void

    public static func startProgress(_ string: String, type: ProgressBar.ProgressType) -> ProgressBar {
        ProgressBar(title: string, type: type, initialProgress: .discreteProgress(totalUnitCount: 0))
    }

    public static func startImageDownload(
        _ image: RemoteVMImage,
        _ callback: ProgressUpdateCallback
    ) async rethrows {
        let size = Format.fileBytes(image.size)
        let bar = ProgressBar(
            title: "Downloading \(image.fileName) (\(size))",
            type: .download,
            initialProgress: Progress.discreteProgress(totalUnitCount: Int64(image.size))
        )
        try await callback(bar)
        bar.succeed()
    }

    public static func startImageUpload(_ path: URL) throws -> ProgressBar {
        let rawSize = try FileManager.default.size(ofObjectAt: path)
        let size = Format.fileBytes(rawSize)

        return ProgressBar(
            title: "Uploading \(path.lastPathComponent) (\(size))",
            type: .upload,
            initialProgress: Progress.discreteProgress(totalUnitCount: Int64(rawSize))
        )
    }

    public static func startFileDownload(_ file: S3Object) -> ProgressBar {
        let size = Format.fileBytes(file.size)
        return ProgressBar(
            title: "Downloading \(file.key) (\(size))",
            type: .download,
            initialProgress: Progress.discreteProgress(totalUnitCount: Int64(file.size))
        )
    }

    public static func startFileDownload(_ url: URL) -> ProgressBar {
        return ProgressBar(
            title: "Downloading \(url)",
            type: .download,
            initialProgress: .discreteProgress(totalUnitCount: 0)
        )
    }

    public static func startIndeterminateProgress(_ string: String) -> ActivityIndicator<CustomActivity> {
        return Console().startIndeterminateProgress(string)
    }
}

// MARK: Static Initializers
extension Console {
    @discardableResult public static func heading(_ message: String) -> Self {
        return Console().heading(message)
    }

    @discardableResult public static func success(_ message: String) -> Self {
        Logger.lib.info(message)
        return Console().success(message)
    }

    @discardableResult public static func error(_ message: String) -> Self {
        Logger.lib.error("\(message)")
        return Console().error(message)
    }

    @discardableResult public static func warn(_ message: String) -> Self {
        Logger.lib.warning("\(message)")
        return Console().warn(message)
    }

    @discardableResult public static func info(_ message: String) -> Self {
        Logger.lib.info("\(message)")
        return Console().info(message)
    }

    @discardableResult public static func log(_ message: String) -> Self {
        Logger.lib.info("\(message)")
        return Console().log(message)
    }

    @discardableResult public static func printList(_ list: [String], title: String) -> Self {
        return Console().printList(list, title: title)
    }

    @discardableResult public static func printTable(data: TableConvertable, columnTitles: [String] = [], columnAlignments: [TableColumnAlignment] = []) -> Self {
        return Console().printTable(data: data.asTable(), columnTitles: columnTitles, columnAlignments: columnAlignments)
    }

    public static func crash(_ error: HostmgrError) -> Never {
        if let description = error.errorDescription {
            Console.error(description)
        }

        Foundation.exit(error.exitCode)
    }

    public static func exit(_ message: String = "", style: ConsoleStyle = .plain) -> Never {
        Console().message(message, style: style)
        Foundation.exit(0)
    }
}

// MARK: Table Support
extension Console {

    public typealias TableRow = [String]
    public typealias Table = [TableRow]
    public enum TableColumnAlignment {
        case left
        case right
    }

    func columnCounts(for table: Table) -> [Int] {
        transpose(matrix: table).map { $0.map(\.monospaceWidth).max() ?? 0 }
    }

    func transpose(matrix: Table) -> Table {
        guard let numberOfColumns = matrix.first?.count else {
            return matrix
        }

        var newTable = Table(repeating: TableRow(repeating: "", count: matrix.count), count: numberOfColumns)

        for (rowIndex, row) in matrix.enumerated() {
            for (colIndex, col) in row.enumerated() {
                newTable[colIndex][rowIndex] = col
            }
        }

        return newTable
    }

    func padString(_ string: String, toLength length: Int, align: TableColumnAlignment) -> String {
        let leftPad = align == .right ? String(repeating: " ", count: max(length - string.count, 0)) : ""
        return "\(leftPad)\(string)".padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

public extension ProgressKind {
    static let installation = ProgressKind(rawValue: "installation")
}

public protocol TableConvertable {
    func asTable() -> Console.Table
}

extension Console.Table: TableConvertable {
    public func asTable() -> Console.Table {
        return self
    }
}
