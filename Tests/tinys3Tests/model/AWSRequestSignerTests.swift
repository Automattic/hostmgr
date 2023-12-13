import XCTest
@testable import tinys3
final class AWSRequestSignerTests: XCTestCase {

    let signer = AWSRequestSigner(credentials: .testDefault, requestDate: .testDefault)

    func testThatRequestAuthenticationCodeIsCorrect() throws {
        let authenticationCode = HMAC256.sign(
            string: "aws4_request", key: HMAC256.sign(
                    string: "s3",
                    key: HMAC256.sign(
                        string: "us-east-1",
                        key: HMAC256.sign(
                            string: formattedDatestamp(from: .testDefault),
                            key: "AWS4" + AWSCredentials.testDefault.secretKey
                        )
                    )
            )
        )

        XCTAssertEqual(authenticationCode, signer.requestAuthenticationCode)
    }
}
