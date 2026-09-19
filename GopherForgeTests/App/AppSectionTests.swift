import XCTest
@testable import GopherForge

final class AppSectionTests: XCTestCase {
    func testTheFourPlacesStayNamedAndPickable() {
        XCTAssertEqual(AppSection.allCases.map(\.id), ["projects", "build", "learn", "settings"])
        for section in AppSection.allCases {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.systemImage.isEmpty)
            XCTAssertEqual(section.id, section.rawValue)
        }
    }
}
