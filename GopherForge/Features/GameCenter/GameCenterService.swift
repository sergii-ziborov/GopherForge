import Foundation
import GameKit

/// Reports achievements to Game Center, when there is a Game Center to report
/// to.
///
/// Two things about this are worth stating rather than discovering. Signing in
/// is the player's choice and can be declined — the app has to work identically
/// either way, so every badge is still earned, stored and shown locally, and
/// Game Center is a mirror rather than the source of truth. And an achievement
/// only lands if an achievement with that exact identifier exists in App Store
/// Connect: until they are created there, reports are rejected, and the app
/// says so rather than pretending they went through.
@MainActor
@Observable
final class GameCenterService {
    enum Status: Equatable {
        case unknown
        case signedOut
        /// Signed in, with the player's display name.
        case signedIn(String)
        /// Reachable but the report was refused, most often because the
        /// achievement is not defined in App Store Connect yet.
        case rejected(String)
    }

    private(set) var status: Status = .unknown
    /// Identifiers Game Center accepted, so the UI can say which badges made
    /// it across rather than implying all of them did.
    private(set) var reportedIdentifiers: Set<String> = []

    private let reporter: any GameCenterReporting

    init(reporter: any GameCenterReporting = LiveGameCenterReporter()) {
        self.reporter = reporter
    }

    var isSignedIn: Bool {
        if case .signedIn = status { return true }
        return false
    }

    var statusDescription: String {
        switch status {
        case .unknown: "Not connected yet."
        case .signedOut:
            "Not signed in. Achievements are still earned and kept on this device."
        case let .signedIn(name): "Signed in as \(name)."
        case let .rejected(reason): reason
        }
    }

    /// Prompts for sign-in. Declining is a normal outcome, not an error.
    ///
    /// Only ever called because someone asked: authenticating presents Apple's
    /// own sheet over whatever they were looking at.
    func authenticate() async {
        status = await reporter.authenticate()
    }

    /// Mirrors progress for a player who is already signed in, and does nothing
    /// at all otherwise — no sheet, no prompt, no interruption.
    func reportIfAlreadySignedIn(_ stats: LearnerStats) async {
        guard reporter.isAlreadySignedIn else {
            status = .signedOut
            return
        }
        status = await reporter.authenticate()
        await report(stats)
    }

    /// Mirrors what has been earned locally.
    ///
    /// Percent-complete rather than a flag, so a badge halfway there shows a
    /// bar in Game Center too. Nothing is reported while signed out — there is
    /// nowhere to report it to, and queuing it would only mean sending stale
    /// numbers later.
    func report(_ stats: LearnerStats) async {
        guard isSignedIn else { return }

        let progress = AchievementCatalog.all.reduce(into: [String: Double]()) { result, badge in
            result[Self.identifier(for: badge)] = badge.fraction(of: stats) * 100
        }
        switch await reporter.report(progress) {
        case .success:
            reportedIdentifiers = Set(progress.keys)
        case let .failure(reason):
            status = .rejected(reason)
        }
    }

    func showDashboard() {
        reporter.presentDashboard()
    }

    /// Game Center identifiers are a flat namespace shared with every other
    /// app, so they carry the bundle's own prefix.
    static func identifier(for achievement: Achievement) -> String {
        "com.sergiiziborov.GopherForge.\(achievement.id)"
    }
}

/// What the service needs from Game Center, behind a protocol so the rules
/// above can be tested without signing anybody in.
@MainActor
protocol GameCenterReporting {
    /// True when Game Center already has a player, so progress can be mirrored
    /// without presenting anything.
    var isAlreadySignedIn: Bool { get }
    func authenticate() async -> GameCenterService.Status
    func report(_ progress: [String: Double]) async -> GameCenterReportOutcome
    func presentDashboard()
}

enum GameCenterReportOutcome: Equatable {
    case success
    case failure(String)
}
