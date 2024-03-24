import XCTest
@testable import tinys3

final class MultipartUploadFileTests: XCTestCase {

    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    var file: MultipartUploadFile!
    var parts: [Range<Int>]!

     override func setUp() async throws {
         FileManager.default.createFile(atPath: path.path, contents: Data())

         let handle = try FileHandle(forWritingTo: path)
         for _ in 0...24 {
             var bytes = [Int8](repeating: 0, count: 1_024_000)
             let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

             if status == errSecSuccess { // Always test the status.
                 try handle.write(contentsOf: Data(bytes: bytes, count: bytes.count))
             }
         }

         try handle.close()

         self.file = try MultipartUploadFile(path: path)
         self.parts = await file.parts
    }

    func testThatRangesDoNotOverlap() async throws {
        for part in parts {
            XCTAssertEqual(parts.filter { $0.overlaps(part) }.count, 1) // Ensure each only overlaps with one: itself
        }
    }

    func testThatCopyingFileResultsInCorrectHash() async throws {
        let fileHash = try sha256Hash(fileAt: path)
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempFile.path, contents: Data())
        let handle = try FileHandle(forWritingTo: tempFile)

        for part in parts {
            let data = try await file[part]
            try handle.write(contentsOf: data)
        }

        XCTAssertEqual(fileHash, try sha256Hash(fileAt: tempFile))
    }

    func testThatPartSizeCalculatorReturnsAppropriateSizes() {
        // swiftlint:disable colon comma
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn:   4.KB),   4    .KB) //   4KB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn:   4.MB),   4    .MB) //   4MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn:  40.MB),   5    .MB) //  40MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 400.MB),   5    .MB) // 400MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 800.MB),   5    .MB) // 800MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn:   4.GB),   8.192.MB) //   4GB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn:  40.GB),  81.92 .MB) //  40GB (*)
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 400.GB), 819.2  .MB) // 400GB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 800.GB),   1.6  .GB) // 800GB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn:   4.TB),   5    .GB) //   4TB
        // (*) 40GB is the approximate size of `xcode-*.vmtemplate.aar` files
        // swiftlint:enable colon comma
    }
}

private extension Double {
    var KB: Int { Int(self * 1024) }
    var MB: Int { Int(self * 1024 * 1024) }
    var GB: Int { Int(self * 1024 * 1024 * 1024) }
    var TB: Int { Int(self * 1024 * 1024 * 1024 * 1024) }
}
