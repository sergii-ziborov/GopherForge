import Foundation

/// A nudge shown beside a lesson that has code, plus the extra gotcha.
///
/// The hint is what to try. The nuance is the thing the Tour or Effective Go
/// mentions in one sentence and people still trip on a week later. Realize
/// uses the verified solution, not this text.
struct LessonHint: Equatable, Identifiable, Sendable {
    let lessonID: String
    /// What to try. Short enough to read before editing.
    let hint: String
    /// One extra catch, not a restatement of the explanation.
    let nuance: String

    var id: String { lessonID }
}
