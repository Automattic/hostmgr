import Foundation
@testable import tinys3

protocol RequestTest {
    var request: AWSRequest { get }

    // Tip: To debug which values should be expected for those tests, use `self.request.printDebugSigningRubyCode()`
    // to print the Ruby code to paste in your Ruby interpreter and get the values generated by the AWS Ruby gem

    func testThatCanonicalUriIsCorrect() throws
    func testThatCanonicalQueryStringIsCorrect() throws
    func testThatCanonicalHeaderStringIsCorrect() throws
    func testThatSignedHeaderStringIsCorrect() throws
    func testThatCanonicalRequestIsValid() throws
    func testThatStringToSignIsValid() throws
    func testThatSignatureIsValid() throws
    func testThatAuthorizationHeaderValueIsCorrect() throws
}
