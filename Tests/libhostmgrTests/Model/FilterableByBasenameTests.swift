import XCTest
@testable import libhostmgr

final class FilterableByBasenameTests: XCTestCase {

    private let remoteImages = [
        "images/one",
        "images/two",
        "images/three"
    ].map { RemoteVMImage.with(key: $0) }

    private let localImages = [
        "/images/one.pvmp",
        "/images/two.pvmp",
        "/images/three.pvmp"
    ].compactMap(LocalVMImage.with)

    func testThatRemoteVMImagesAreFilteredCorrectlyWhenIncludingItems() throws {
        XCTAssertEqual(
            remoteImages.filter(includingItemsIn: ["one", "three"]),
            [remoteImages.first!, remoteImages.last!]
        )
    }

    func testThatLocalVMImagesAreFilteredCorrectlyWhenIncludingItems() throws {
        XCTAssertEqual(
            localImages.filter(includingItemsIn: ["one", "three"]),
            [localImages.first!, localImages.last!]
        )
    }

    func testThatRemoteVMImagesAreFilteredCorrectlyWhenExcludingItems() throws {
        XCTAssertEqual(
            remoteImages.filter(excludingItemsIn: ["one", "three"]),
            [remoteImages[1]]
        )
    }

    func testThatLocalVMImagesAreFilteredCorrectlyWhenExcludingItems() throws {
        XCTAssertEqual(
            localImages.filter(excludingItemsIn: ["one", "three"]),
            [localImages[1]]
        )
    }
}
