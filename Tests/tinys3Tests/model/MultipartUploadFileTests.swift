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
        // swiftlint:disable:next identifier_name
        func 💾(_ value: Double, _ unit: UnitInformationStorage) -> Int {
            let bits = unit.converter.baseUnitValue(fromValue: value)
            let bytes = UnitInformationStorage.bytes.converter.value(fromBaseUnitValue: bits)
            return Int(bytes)
        }

        // Files which are smaller than the minimum part size (5MB) will have a single part,
        // whose size will thus just be the size of the whole file
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(4, .kibibytes)), 💾(4, .kibibytes))       //   4KB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(4, .mebibytes)), 💾(4, .mebibytes))       //   4MB

        // Files bigger than the minimum part size (5MB) should have multiple parts,
        // with each part (except last) being within 5MB...5GB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(40, .mebibytes)), 💾(5, .mebibytes))      //  40MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(400, .mebibytes)), 💾(5, .mebibytes))     // 400MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(800, .mebibytes)), 💾(5, .mebibytes))     // 800MB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(4, .gibibytes)), 💾(8.192, .mebibytes))   //   4GB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(40, .gibibytes)), 💾(81.92, .mebibytes))  //  40GB (*)
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(400, .gibibytes)), 💾(819.2, .mebibytes)) // 400GB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(800, .gibibytes)), 💾(1.6, .gibibytes))   // 800GB

        // Files even bigger than that should not have their individual parts be higher than the max part size (5GB)
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(4, .tebibytes)), 💾(5, .gibibytes))       //   4TB
        XCTAssertEqual(PartSizeCalculator.calculate(basedOn: 💾(8, .tebibytes)), 💾(5, .gibibytes))       //   8TB
        // (*) 40GB is the approximate size of `xcode-*.vmtemplate.aar` files
    }
}
