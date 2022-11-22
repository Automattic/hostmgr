import XCTest
@testable import libhostmgr

final class EnvFileParserTests: XCTestCase {
    private var envFile: EnvFile!

    override func setUpWithError() throws {
        self.envFile = try EnvFile.from(getPathForEnvFile(named: "dotenv-fixtures"))
    }

    func testThatUnquotedStringsCanBeParsed() throws {
        XCTAssertEqual("foo", self.envFile["UNQUOTED_STRING"])
    }

    func testThatQuotedStringsCanBeParsed() throws {
        XCTAssertEqual("foo", self.envFile["QUOTED_STRING"])
    }

    func testThatUnquotedStringsWithLeadingSpacesAreTrimmed() throws {
        XCTAssertEqual("foo", self.envFile["UNQUOTED_STRING_WITH_LEADING_SPACE_IN_VALUE"])
    }

    func testThatUnquotedStringsWithTrailingSpacesAreTrimmed() throws {
        XCTAssertEqual("foo", self.envFile["UNQUOTED_STRING_WITH_TRAILING_SPACE_IN_VALUE"])
    }

    func testThatQuotedStringsWithLeadingSpacesAreNotTrimmed() throws {
        XCTAssertEqual(" foo", self.envFile["STRING_WITH_QUOTED_LEADING_SPACE"])
    }

    func testThatQuotedStringsWithTrailingSpacesAreNotTrimmed() throws {
        XCTAssertEqual("foo ", self.envFile["STRING_WITH_QUOTED_TRAILING_SPACE"])
    }

    func testThatQuotedStringWithLeadingQuoteHasQuotePreserved() throws {
        XCTAssertEqual("\"foo", self.envFile["STRING_WITH_LEADING_QUOTE"])
    }

    func testThatQuotedStringsWithEmbeddedQuoteHasQuotePreserved() throws {
        XCTAssertEqual("foo\"bar", self.envFile["UNQUOTED_STRING_WITH_EMBEDDED_QUOTE"])
    }

    func testThatQuotedStringsWithTrailingQuoteHasQuotePreserved() throws {
        XCTAssertEqual("foo\"", self.envFile["STRING_WITH_TRAILING_QUOTE"])
    }

    func testThatKeyWithoutValueReturnEmptyString() throws {
        XCTAssertTrue(try XCTUnwrap(self.envFile["STRING_WITH_NO_VALUE"]).isEmpty)
    }

    func testThatKeyWithWhitespaceValueReturnsEmptyString() throws {
        XCTAssertTrue(try XCTUnwrap(self.envFile["STRING_WITH_WHITESPACE_VALUE"]).isEmpty)
    }

    func testThatUnquotedValueWithEqualSignIsParsedCorrectly() throws {
        XCTAssertEqual("foo=bar", self.envFile["UNQUOTED_STRING_WITH_EQUAL_SIGN"])
    }

    func testThatQuotedValueWithEqualSignIsParsedCorrectly() throws {
        XCTAssertEqual("foo=bar", self.envFile["QUOTED_STRING_WITH_EQUAL_SIGN"])
    }

    func testThatEmbeddedNewlineIsParsedCorrectly() throws {
        XCTAssertEqual("foo\\nbar", self.envFile["QUOTED_STRING_WITH_NEWLINE"])
    }

    func testThatQuotedCommentedStringIgnoresComment() throws {
        XCTAssertEqual("foo", self.envFile["COMMENTED_QUOTED_STRING"])
    }

    func testThatUnquotedCommentedStringIgnoresComment() throws {
        XCTAssertEqual("foo", self.envFile["COMMENTED_UNQUOTED_STRING"])
    }

    func testThatKeysWithoutEqualSignAreIgnored() throws {
        XCTAssertNil(self.envFile["IGNORED_STRING_WITH_NO_EQUAL_SIGN"])
    }
}
