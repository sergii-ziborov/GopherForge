import XCTest
@testable import GopherForge

final class FilesDrawerGestureTests: XCTestCase {
    func testOpenNeedsTheLeadingEdgeAndAHorizontalFlick() {
        XCTAssertTrue(
            FilesDrawerGesture.shouldOpen(startX: FilesDrawerGesture.edgeWidth, translationWidth: 80)
        )
        XCTAssertFalse(
            FilesDrawerGesture.shouldOpen(
                startX: FilesDrawerGesture.edgeWidth + 0.5,
                translationWidth: 80
            )
        )
        XCTAssertFalse(
            FilesDrawerGesture.shouldOpen(
                startX: 8,
                translationWidth: FilesDrawerGesture.minimumTranslation - 1
            )
        )
    }

    func testADiagonalEditorScrollDoesNotOpenOrClose() {
        XCTAssertFalse(
            FilesDrawerGesture.shouldOpen(
                startX: 8,
                translation: CGSize(width: 50, height: 50)
            )
        )
        XCTAssertFalse(
            FilesDrawerGesture.shouldClose(translation: CGSize(width: -50, height: 50))
        )
    }

    func testCloseNeedsALeftwardHorizontalFlick() {
        XCTAssertTrue(
            FilesDrawerGesture.shouldClose(
                translationWidth: -FilesDrawerGesture.minimumTranslation
            )
        )
        XCTAssertFalse(FilesDrawerGesture.shouldClose(translationWidth: -10))
        XCTAssertFalse(FilesDrawerGesture.shouldClose(translationWidth: 80))
    }
}
