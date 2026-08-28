import Foundation
import GameKit
import UIKit

/// The real Game Center.
///
/// Kept apart from the service so the rules — what is reported, when, and what
/// happens when it is refused — can be tested without a signed-in player, which
/// is not something a test can arrange.
@MainActor
struct LiveGameCenterReporter: GameCenterReporting {
    var isAlreadySignedIn: Bool { GKLocalPlayer.local.isAuthenticated }

    func authenticate() async -> GameCenterService.Status {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            GKLocalPlayer.local.authenticateHandler = { viewController, _ in
                // The handler can fire more than once over a session; only the
                // first outcome answers this call.
                if let viewController {
                    Self.present(viewController)
                    return
                }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(
                    returning: GKLocalPlayer.local.isAuthenticated
                        ? .signedIn(GKLocalPlayer.local.displayName)
                        : .signedOut
                )
            }
        }
    }

    func report(_ progress: [String: Double]) async -> GameCenterReportOutcome {
        let achievements = progress.map { identifier, percent -> GKAchievement in
            let achievement = GKAchievement(identifier: identifier)
            achievement.percentComplete = min(100, max(0, percent))
            achievement.showsCompletionBanner = true
            return achievement
        }

        do {
            try await GKAchievement.report(achievements)
            return .success
        } catch {
            // Overwhelmingly this is an identifier that does not exist in App
            // Store Connect yet, and saying so is more use than the raw error.
            return .failure(
                "Game Center refused the report: \(error.localizedDescription). "
                    + "Two things have to be in place: the Game Center capability enabled "
                    + "for this app, and each achievement created in App Store Connect "
                    + "with the identifier the app reports."
            )
        }
    }

    func presentDashboard() {
        let viewController = GKGameCenterViewController(state: .achievements)
        Self.present(viewController)
    }

    private static func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else {
            return
        }

        if let dashboard = viewController as? GKGameCenterViewController {
            dashboard.gameCenterDelegate = DashboardDismisser.shared
        }
        root.present(viewController, animated: true)
    }
}

/// Game Center's dashboard will not close itself.
///
/// `nonisolated` on the conformance because GameKit's delegate is not declared
/// as main-actor, and the hop is made explicitly inside rather than claimed by
/// the type.
private final class DashboardDismisser: NSObject, GKGameCenterControllerDelegate {
    nonisolated(unsafe) static let shared = DashboardDismisser()

    nonisolated func gameCenterViewControllerDidFinish(
        _ controller: GKGameCenterViewController
    ) {
        Task { @MainActor in controller.dismiss(animated: true) }
    }
}
