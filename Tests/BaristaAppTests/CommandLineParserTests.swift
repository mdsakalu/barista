import XCTest
@testable import BaristaApp

final class CommandLineParserTests: XCTestCase {
    func testPreservesEmptyQuotedArguments() {
        XCTAssertEqual(
            CommandLineParser.parse(#"/usr/bin/printf "%s" """#),
            ["/usr/bin/printf", "%s", ""]
        )
    }

    func testCombinesQuotedAndUnquotedSegments() {
        XCTAssertEqual(
            CommandLineParser.parse(#"tool pre"middle value"post"#),
            ["tool", "premiddle valuepost"]
        )
    }

    func testRejectsUnmatchedQuotes() {
        XCTAssertNil(CommandLineParser.parse(#"tool "unfinished"#))
    }
}
