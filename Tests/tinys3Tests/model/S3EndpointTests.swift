import XCTest
@testable import tinys3

final class S3EndpointTests: XCTestCase {

    let defaultEndpoint = S3Endpoint.default
    let acceleratedEndpoint = S3Endpoint.accelerated

    func testThatDefaultEndpointUsesBucketSubdomain() throws {
        XCTAssertEqual(
            "my-test-bucket.s3.amazonaws.com",
            defaultEndpoint.hostname(forBucket: "my-test-bucket", inRegion: "us-east-1")
        )
    }

    func testThatAcceleratedEndpointUsesBucketSubdomain() throws {
        XCTAssertEqual(
            "my-test-bucket.s3-accelerate.amazonaws.com",
            acceleratedEndpoint.hostname(forBucket: "my-test-bucket", inRegion: "us-east-1")
        )
    }
}
