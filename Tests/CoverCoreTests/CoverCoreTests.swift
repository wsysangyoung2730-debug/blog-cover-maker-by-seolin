import XCTest
@testable import CoverCore

final class CoverCoreTests: XCTestCase {
    func testCanvasMatchesOriginalExportSize() {
        XCTAssertEqual(CoverConstants.canvasSize, 1080)
    }
}
