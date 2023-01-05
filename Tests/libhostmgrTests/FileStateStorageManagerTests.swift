import XCTest
@testable import libhostmgr

class FileStateRepositoryTests: XCTestCase {

    private let stateRepository = FileStateRepository(
        stateStorageDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("FileStateRepositoryTests", isDirectory: true)
    )

    override func tearDownWithError() throws {
        try stateRepository.deleteAll()
    }

    func testThatDirectoryStructureIsBuiltForStateOnSave() throws {
        try stateRepository.write("Hello", toKey: #function)

        let destination = stateRepository.stateStorageDirectory.appendingPathComponent(#function)
        XCTAssertTrue(FileManager.default.fileExists(at: destination))
    }

    func testThatFileIsRemovedForStateOnRemove() throws {
        try stateRepository.write("Hello", toKey: #function)

        let destination = stateRepository.stateStorageDirectory.appendingPathComponent(#function)
        try stateRepository.delete(key: #function)
        XCTAssertFalse(FileManager.default.fileExists(at: destination))
    }

    func testThatKeyCanBeRead() throws {
        let expectedString = UUID().uuidString
        try stateRepository.write(expectedString, toKey: #function)
        XCTAssertEqual(expectedString, try stateRepository.read(fromKey: #function))
    }

    func testThatKeyCanBeUpdated() throws {
        try stateRepository.write("Initial Value", toKey: #function)

        let expectedString = UUID().uuidString
        try stateRepository.write(expectedString, toKey: #function)
        XCTAssertEqual(expectedString, try stateRepository.read(fromKey: #function))
    }
}
