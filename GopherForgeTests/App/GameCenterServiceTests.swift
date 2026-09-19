import XCTest
@testable import GopherForge

/// What the app reports to Game Center, and what it does when Game Center says
/// no.
///
/// Signing a player in is not something a test can arrange, so the real
/// reporter sits behind a protocol and these check the rules around it: that
/// declining to sign in is a normal outcome rather than an error, that nothing
/// is sent while signed out, and that a refusal is surfaced rather than
/// swallowed.
@MainActor
final class GameCenterServiceTests: XCTestCase {
    private final class FakeReporter: GameCenterReporting {
        var isAlreadySignedIn = false
        var authenticationResult: GameCenterService.Status = .signedOut
        var reportResult: GameCenterReportOutcome = .success
        private(set) var reported: [[String: Double]] = []
        private(set) var dashboardShown = false

        func authenticate() async -> GameCenterService.Status { authenticationResult }

        func report(_ progress: [String: Double]) async -> GameCenterReportOutcome {
            reported.append(progress)
            return reportResult
        }

        func presentDashboard() { dashboardShown = true }
    }

    private var everything: LearnerStats {
        var stats = LearnerStats()
        stats.programsRun = 999
        return stats
    }

    func testDecliningToSignInIsNotAnError() async {
        let reporter = FakeReporter()
        reporter.authenticationResult = .signedOut
        let service = GameCenterService(reporter: reporter)

        await service.authenticate()

        XCTAssertFalse(service.isSignedIn)
        XCTAssertTrue(
            service.statusDescription.contains("kept on this device"),
            "the app should say the badges still work, got: \(service.statusDescription)"
        )
    }

    /// Nothing is sent while signed out: there is nowhere to send it, and
    /// queuing it would only mean sending stale numbers later.
    func testNothingIsReportedWhileSignedOut() async {
        let reporter = FakeReporter()
        reporter.authenticationResult = .signedOut
        let service = GameCenterService(reporter: reporter)
        await service.authenticate()

        await service.report(everything)

        XCTAssertTrue(reporter.reported.isEmpty)
    }

    /// Game Center has no notion of tiers, so each rung is its own achievement
    /// there — four per badge rather than one.
    func testEveryLevelIsReportedAsItsOwnAchievement() async throws {
        let reporter = FakeReporter()
        reporter.authenticationResult = .signedIn("ada")
        let service = GameCenterService(reporter: reporter)
        await service.authenticate()

        await service.report(everything)

        let sent = try XCTUnwrap(reporter.reported.first)
        XCTAssertEqual(sent.count, AchievementCatalog.totalLevelCount)

        let badge = AchievementCatalog.all[0]
        for level in badge.levels {
            XCTAssertEqual(
                sent[GameCenterService.identifier(for: badge, level: level)],
                100,
                "\(level.rank) should report as complete when everything is earned"
            )
        }
        for percent in sent.values {
            XCTAssertGreaterThanOrEqual(percent, 0)
            XCTAssertLessThanOrEqual(percent, 100)
        }
    }

    /// Identifiers are a flat namespace shared with every other app on Game
    /// Center, so two rungs colliding would silently overwrite each other.
    func testEveryLevelIdentifierIsDistinct() {
        var identifiers: Set<String> = []
        for badge in AchievementCatalog.all {
            for level in badge.levels {
                identifiers.insert(GameCenterService.identifier(for: badge, level: level))
            }
        }

        XCTAssertEqual(identifiers.count, AchievementCatalog.totalLevelCount)
    }

    /// Overwhelmingly this means the achievement does not exist in App Store
    /// Connect yet, and the app has to say so rather than look successful.
    func testARefusedReportIsSurfaced() async {
        let reporter = FakeReporter()
        reporter.authenticationResult = .signedIn("ada")
        reporter.reportResult = .failure("no such achievement")
        let service = GameCenterService(reporter: reporter)
        await service.authenticate()

        await service.report(everything)

        XCTAssertFalse(service.isSignedIn, "a refusal replaces the signed-in state with the reason")
        XCTAssertTrue(service.statusDescription.contains("no such achievement"))
        XCTAssertTrue(service.reportedIdentifiers.isEmpty)
    }

    /// Opening a screen must not present Apple's sign-in sheet. Being asked to
    /// sign in to something for looking at a list is how people close an app.
    func testNothingIsPresentedForAPlayerWhoIsNotSignedIn() async {
        let reporter = FakeReporter()
        reporter.isAlreadySignedIn = false
        reporter.authenticationResult = .signedIn("ada")
        let service = GameCenterService(reporter: reporter)

        await service.reportIfAlreadySignedIn(everything)

        XCTAssertFalse(service.isSignedIn, "no sign-in should have been attempted")
        XCTAssertTrue(reporter.reported.isEmpty)
    }

    func testAnAlreadySignedInPlayerIsMirroredWithoutAsking() async {
        let reporter = FakeReporter()
        reporter.isAlreadySignedIn = true
        reporter.authenticationResult = .signedIn("ada")
        let service = GameCenterService(reporter: reporter)

        await service.reportIfAlreadySignedIn(everything)

        XCTAssertTrue(service.isSignedIn)
        XCTAssertEqual(reporter.reported.count, 1)
    }

    /// Game Center's namespace is shared with every other app, so identifiers
    /// carry the bundle's own prefix.
    func testIdentifiersArePrefixed() {
        for badge in AchievementCatalog.all {
            for level in badge.levels {
                XCTAssertTrue(
                    GameCenterService.identifier(for: badge, level: level)
                        .hasPrefix("com.sergiiziborov.GopherForge.")
                )
            }
        }
    }
}
