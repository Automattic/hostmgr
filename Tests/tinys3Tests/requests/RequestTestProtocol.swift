import Foundation
@testable import tinys3

protocol RequestTest {
    var request: AWSRequest { get }

    func testThatCanonicalUriIsCorrect() throws
    func testThatCanonicalQueryStringIsCorrect() throws
    func testThatCanonicalHeaderStringIsCorrect() throws
    func testThatSignedHeaderStringIsCorrect() throws
    func testThatCanonicalRequestIsValid() throws
    func testThatStringToSignIsValid() throws
    func testThatSignatureIsValid() throws
    func testThatAuthorizationHeaderValueIsCorrect() throws
}
