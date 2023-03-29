import Foundation
import TSCBasic
import XCTest
import libhostmgr

class GitMirrorTests: XCTestCase {

    func testManifestAreSorted() throws {
        let manifest = try getManifest(withFiles: [
            "automattic/day-one-apple/2023-03-28.git.tar",
            "automattic/pocket-casts-ios/2023-03-28.git.tar",
            "automattic/simplenote-ios/2023-03-28.git.tar"
        ])

        XCTAssertEqual(
            manifest,
            """
            automattic/day-one-apple/2023-03-28.git.tar
            automattic/pocket-casts-ios/2023-03-28.git.tar
            automattic/simplenote-ios/2023-03-28.git.tar
            """
        )
    }

    func testManifestOnlyContainsTarFiles() throws {
        let manifest = try getManifest(withFiles: [
            "automattic/day-one-apple/2023-03-28.git.tar",
            "automattic/day-one-apple/na",
            "automattic/pocket-casts-ios/2023-03-28.git.tar",
            "automattic/pocket-casts-ios/nah",
            "automattic/simplenote-ios/2023-03-28.git.tar"
        ])
        XCTAssertEqual(
            manifest,
            """
            automattic/day-one-apple/2023-03-28.git.tar
            automattic/pocket-casts-ios/2023-03-28.git.tar
            automattic/simplenote-ios/2023-03-28.git.tar
            """
        )
    }

    func testManifestOnlyContainsTheMostRecentOne() throws {
        let manifest = try getManifest(withFiles: [
            "automattic/day-one-apple/2023-03-27.git.tar",
            "automattic/day-one-apple/2023-03-28.git.tar"
        ])
        XCTAssertEqual(manifest, "automattic/day-one-apple/2023-03-28.git.tar")
    }

    private func getManifest(withFiles files: [String]) throws -> String {
        let gitMirrorDir = AbsolutePath("/git-mirrors")
        let fileSystem = InMemoryFileSystem()
        try files.forEach {
            let path = gitMirrorDir.appending(RelativePath($0))
            try fileSystem.createDirectory(path.parentDirectory, recursive: true)
            try fileSystem.writeFileContents(path, bytes: "")
            // Also create an empty directory and an empty file to mess with the tests.
            try fileSystem.createDirectory(path.parentDirectory.appending(component: "dir"), recursive: true)
            try fileSystem.writeFileContents(path.parentDirectory.appending(component: "empty-file"), bytes: "")
        }
        return try gitMirrorsManifest(fileSystem: fileSystem, gitMirrorStorageDirectory: gitMirrorDir.asURL)
    }

}
