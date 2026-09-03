import Foundation

/// The addresses and the version string the app has to be able to show.
///
/// Gathered here because two of them are submission requirements rather than
/// decoration: App Review guideline 5.1.1(i) asks for the privacy policy to be
/// reachable from inside the app, and every listing needs a support URL that
/// resolves. Keeping them in one place means a move is one edit rather than a
/// hunt, and a test can check they are well formed.
enum AppLinks {
    /// Force-unwrapped on purpose: these are compile-time constants, and a URL
    /// that fails to parse is a build-time mistake rather than a runtime state
    /// worth handling. `AppLinksTests` fails first if one is malformed.
    static let privacyPolicy = URL(string: "https://github.com/sergii-ziborov/GopherForge/blob/main/PRIVACY.md")!
    static let support = URL(string: "https://github.com/sergii-ziborov/GopherForge/blob/main/SUPPORT.md")!

    /// What Settings shows, and what a support request should quote.
    static var versionSummary: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
