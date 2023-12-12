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
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 4094), 4094)                     //    4kb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 4_094_000), 4_094_000)           //    4mb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 40_094_000), 5_000_000)          //   40mb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 400_094_000), 33_341_166)        //  400mb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 4_000_094_000), 333_341_166)     //    4gb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 40_000_094_000), 3_333_341_166)  //   40gb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 400_000_094_000), 4_900_000_000) //  400gb
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 400_000_094_000), 4_900_000_000) //    4tb
    }
}
