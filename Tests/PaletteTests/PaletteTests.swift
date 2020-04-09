import XCTest
@testable import Palette

final class PaletteTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Palette().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
