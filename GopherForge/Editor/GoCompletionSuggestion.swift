import Foundation

/// One offered completion.
///
/// Nothing is ever inserted without an explicit action: a suggestion is
/// reviewed, then accepted. That rule is what keeps an offline table and a
/// model-backed suggestion interchangeable without changing how it feels.
struct GoCompletionSuggestion: Identifiable, Equatable, Sendable {
    enum Origin: String, Sendable {
        /// A small deterministic table that ships with the app and works with
        /// no network, no model and no device requirements.
        case bundled
        /// The on-device system model, when the hardware and the user's
        /// settings allow it.
        case onDeviceModel
    }

    let id = UUID()
    let title: String
    let detail: String
    let insertion: String
    let origin: Origin
    let conceptTag: String?
}
