import XCTest
@testable import libhostmgr

final class FilterableByBasenameTests: XCTestCase {

    private let remoteImages = [
        "images/one",
        "images/two",
        "images/three"
    ].map { RemoteVMImage.with(key: $0) }

    func testThatRemoteVMImagesAreFilteredCorrectlyWhenIncludingItems() throws {
        XCTAssertEqual(
            remoteImages.filter(includingItemsIn: ["one", "three"]),
            [remoteImages.first!, remoteImages.last!]
        )
    }

    func testThatRemoteVMImagesAreFilteredCorrectlyWhenExcludingItems() throws {
        XCTAssertEqual(
            remoteImages.filter(excludingItemsIn: ["one", "three"]),
            [remoteImages[1]]
        )
    }
}
