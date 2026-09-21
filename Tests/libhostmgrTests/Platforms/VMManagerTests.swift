import XCTest
import Foundation
@testable import libhostmgr

final class VMManagerTests: XCTestCase {

    /// Test that unpackVM throws the correct error when a VM already exists at the destination
    func testUnpackVMThrowsWhenVMAlreadyExists() async throws {
        let vmName = "test-vm-\(UUID().uuidString)"
        let expectedVMPath = Paths.toVMTemplate(named: vmName)

        // Create the destination directory to simulate an existing VM
        try FileManager.default.createDirectory(at: expectedVMPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: expectedVMPath)
        }

        let vmManager = VMManager()

        do {
            try await vmManager.unpackVM(name: vmName)
            XCTFail("Expected CocoaError.fileWriteFileExists to be thrown")
        } catch let error as CocoaError {
            XCTAssertEqual(error.code, CocoaError.fileWriteFileExists)
        }
    }

    /// Test that unpackVM throws an error when the source archive doesn't exist
    func testUnpackVMThrowsWhenArchiveDoesNotExist() async throws {
        let vmName = "non-existent-vm-\(UUID().uuidString)"
        let vmManager = VMManager()

        do {
            try await vmManager.unpackVM(name: vmName)
            XCTFail("Expected error when archive does not exist")
        } catch {
            XCTAssertTrue(true, "Should throw error for missing archive")
        }
    }

    /// Test that temporary directories are properly cleaned up when unpackVM fails
    func testUnpackVMCleansUpTempDirectoryOnFailure() async throws {
        let vmName = "test-vm-cleanup-\(UUID().uuidString)"
        let vmManager = VMManager()

        do {
            try await vmManager.unpackVM(name: vmName)
            XCTFail("Expected unpack to fail due to missing archive")
        } catch {
            // Verify that no temporary directories remain after failure
            let tempDirs = try FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.contains("hostmgr-vm-unpack-\(vmName)") }

            XCTAssertTrue(tempDirs.isEmpty, "Temporary directories should be cleaned up on failure")
        }
    }

    /// Test that when unpacking an invalid archive fails, no folder is left at the final destination
    func testUnpackVMDoesNotLeaveDestinationFolderOnInvalidArchive() async throws {
        let vmName = "test-invalid-archive-\(UUID().uuidString)"
        let archivePath = Paths.toArchivedVM(named: vmName)
        let finalDestination = Paths.toVMTemplate(named: vmName)

        // Create an invalid archive (just a text file instead of proper .aar format)
        try FileManager.default.createDirectory(
            at: archivePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "invalid archive content".write(to: archivePath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: archivePath)
            try? FileManager.default.removeItem(at: finalDestination)
        }

        let vmManager = VMManager()

        // Verify destination doesn't exist before attempting unpack
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalDestination.path))

        do {
            try await vmManager.unpackVM(name: vmName)
            XCTFail("Expected unpack to fail with invalid archive")
        } catch {
            // After failure, verify no folder was left at the final destination
            XCTAssertFalse(FileManager.default.fileExists(atPath: finalDestination.path),
                          "Final destination should not exist after failed unpack")
        }
    }
}
