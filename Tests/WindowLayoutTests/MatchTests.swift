import Foundation
import WindowLayoutCore
import XCTest

final class MatchTests: XCTestCase {
    private func window(title: String, index: Int) -> SavedWindow {
        SavedWindow(bundleID: "com.example", appName: "Example", title: title, index: index, x: 0, y: 0, width: 0.5, height: 0.5)
    }

    func testTitleMatchWinsOverIndex() {
        XCTAssertEqual(match(saved: window(title: "B", index: 0), titles: ["A", "B"]), 1)
    }

    func testFallsBackToIndexWhenTitleMissing() {
        XCTAssertEqual(match(saved: window(title: "Z", index: 1), titles: ["A", "B"]), 1)
    }

    func testOutOfBoundsIndexReturnsNil() {
        XCTAssertNil(match(saved: window(title: "Z", index: 5), titles: ["A", "B"]))
        XCTAssertNil(match(saved: window(title: "Z", index: 0), titles: []))
    }
}
