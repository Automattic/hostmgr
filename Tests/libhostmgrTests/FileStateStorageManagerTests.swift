import XCTest
@testable import libhostmgr

class FileStateStorageManagerTests: XCTestCase {

    private let stateStorageManager = FileStateStorage(
        stateStorageDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("hostmgr", isDirectory: true)
            .appendingPathComponent("FileStateStorageManagerTests", isDirectory: true)
    )

    override func tearDownWithError() throws {
        try stateStorageManager.deleteAll()
    }

    func testThatDirectoryStructureIsBuiltForStateOnSave() throws {
        try stateStorageManager.write("Hello", toKey: #function)

        let destination = stateStorageManager.stateStorageDirectory.appendingPathComponent(#function)
        XCTAssertTrue(FileManager.default.fileExists(at: destination))
    }

    func testThatFileIsRemovedForStateOnRemove() throws {
        try stateStorageManager.write("Hello", toKey: #function)

        let destination = stateStorageManager.stateStorageDirectory.appendingPathComponent(#function)
        try stateStorageManager.delete(key: #function)
        XCTAssertFalse(FileManager.default.fileExists(at: destination))
    }

    func testThatKeyCanBeRead() throws {
        let expectedString = UUID().uuidString
        try stateStorageManager.write(expectedString, toKey: #function)
        XCTAssertEqual(expectedString, try stateStorageManager.read(fromKey: #function))
    }

    func testThatKeyCanBeUpdated() throws {
        try stateStorageManager.write("Initial Value", toKey: #function)

        let expectedString = UUID().uuidString
        try stateStorageManager.write(expectedString, toKey: #function)
        XCTAssertEqual(expectedString, try stateStorageManager.read(fromKey: #function))
    }
}
