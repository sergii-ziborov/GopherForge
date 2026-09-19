import XCTest
@testable import GopherForge

/// The icons in the file list.
///
/// The point of an icon here is to distinguish three files that are all `.go`
/// — the entry point, a test and an ordinary source file — so those cases are
/// what this pins down.
final class SourceFileBadgeTests: XCTestCase {
    func testTheThreeGoFilesLookDifferent() {
        XCTAssertEqual(SourceFileBadge.of(path: "main.go"), .entryPoint)
        XCTAssertEqual(SourceFileBadge.of(path: "reverse_test.go"), .test)
        XCTAssertEqual(SourceFileBadge.of(path: "greet.go"), .source)

        let symbols = Set([SourceFileBadge.entryPoint, .test, .source].map(\.systemImage))
        XCTAssertEqual(symbols.count, 3, "three roles should not share one symbol")
    }

    /// A test file called `main_test.go` is a test, not an entry point. Order
    /// of checks decides this, so it is worth stating.
    func testATestFileNamedMainIsStillATest() {
        XCTAssertEqual(SourceFileBadge.of(path: "main_test.go"), .test)
        XCTAssertEqual(SourceFileBadge.of(path: "cmd/tool/main_test.go"), .test)
    }

    func testModuleFilesAreRecognisedByName() {
        XCTAssertEqual(SourceFileBadge.of(path: "go.mod"), .module)
        XCTAssertEqual(SourceFileBadge.of(path: "go.sum"), .checksums)
        XCTAssertEqual(SourceFileBadge.of(path: "nested/go.mod"), .module)
    }

    func testDocumentationAndAnythingElse() {
        XCTAssertEqual(SourceFileBadge.of(path: "README.md"), .documentation)
        XCTAssertEqual(SourceFileBadge.of(path: "notes.txt"), .documentation)
        XCTAssertEqual(SourceFileBadge.of(path: "data.bin"), .other)
    }

    func testEveryBadgeHasSomethingForVoiceOverToSay() {
        for badge in SourceFileBadge.allCases {
            XCTAssertFalse(badge.accessibilityDescription.isEmpty)
            XCTAssertFalse(
                badge.accessibilityDescription.contains("chevron"),
                "VoiceOver should hear the role, not the symbol's name"
            )
        }
    }
}

/// The theme setting.
final class AppearanceModeTests: XCTestCase {
    func testAutoDoesNotOverrideTheSystem() {
        XCTAssertNil(
            AppearanceMode.system.colorScheme,
            "Auto has to leave the scheme unset, or it guesses and is wrong until a redraw"
        )
        XCTAssertEqual(AppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark)
    }

    /// A stored preference must never be the reason the app fails to start.
    func testAnUnknownStoredValueFallsBackToAuto() {
        XCTAssertEqual(AppearanceMode.stored(nil), .system)
        XCTAssertEqual(AppearanceMode.stored(""), .system)
        XCTAssertEqual(AppearanceMode.stored("sepia"), .system)
        XCTAssertEqual(AppearanceMode.stored("dark"), .dark)
    }

    func testEveryModeIsNamedAndPickable() {
        XCTAssertEqual(AppearanceMode.allCases.count, 3)
        for mode in AppearanceMode.allCases {
            XCTAssertFalse(mode.title.isEmpty)
            XCTAssertFalse(mode.systemImage.isEmpty)
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }
}
