import XCTest
@testable import tinys3

final class S3MultipartUploadCompleteXMLBuilderTests: XCTestCase {

    func testThatXMLDocumentOutputIsCorrect() throws {
        let builder = S3MultipartUploadCompleteXMLBuilder()
        XCTAssertEqual(builder.build(), try R.string("CompleteMultipartUploadDocument"))
    }

    func testThatXMLDocumentWithPartIsCorrect() throws {
        let builder = S3MultipartUploadCompleteXMLBuilder()
        builder.addPart(.init(number: 1234, eTag: "a9021bcb06da4ad5a7798b206a2508a7c2231ca183bd20492b1f0612883ab1e5"))
        XCTAssertEqual(builder.build(options: .prettyPrinted), try R.string("CompleteMultipartUploadRequest"))
    }
}
