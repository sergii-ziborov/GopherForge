import XCTest
@testable import GopherForge

final class LaunchOptionsTests: XCTestCase {
    /// The default has to hold when nothing is passed, because that is how the
    /// app actually launches for a user.
    func testDefaultsToProjectsWithNoArguments() {
        XCTAssertEqual(LaunchOptions.initialSection, .projects)
        XCTAssertNil(LaunchOptions.initialScreen)
    }

    func testEverySectionRoundTripsThroughItsIdentifier() {
        for section in AppSection.allCases {
            XCTAssertEqual(AppSection(rawValue: section.rawValue), section)
        }
    }

    func testEveryScreenRoundTripsThroughItsIdentifier() {
        for screen in [LaunchOptions.Screen.lab, .review] {
            XCTAssertEqual(LaunchOptions.Screen(rawValue: screen.rawValue), screen)
        }
    }
}
