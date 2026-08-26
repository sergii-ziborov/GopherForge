import Foundation

/// Turns a trace into the sentence a reviewer would say out loud.
///
/// Every diagnosis names the goroutine and the channel involved, because
/// "deadlock" on its own teaches nothing. A trace with nothing wrong produces
/// no diagnosis rather than a reassuring one.
struct ConcurrencyDiagnosis: Identifiable, Equatable, Sendable {
    let id = UUID()
    let conceptTag: String
    let headline: String
    let detail: String

    static func diagnose(_ trace: ConcurrencyTrace, runtimeStderr: String = "") -> [ConcurrencyDiagnosis] {
        var diagnoses: [ConcurrencyDiagnosis] = []

        for event in trace.sendsAfterClose {
            diagnoses.append(
                ConcurrencyDiagnosis(
                    conceptTag: GoConcept.channelClose,
                    headline: "\(event.actor) sent on a closed channel",
                    detail: """
                    \(event.subject ?? "The channel") was already closed when \
                    \(event.actor) sent on it. Closing belongs to the goroutine \
                    that owns sending, and no one may send afterwards.
                    """
                )
            )
        }

        for actor in trace.stuckActors {
            let subject = trace.events(for: actor).last?.subject ?? "a channel"
            diagnoses.append(
                ConcurrencyDiagnosis(
                    conceptTag: GoConcept.goroutineLeak,
                    headline: "\(actor) is still blocked when the program ends",
                    detail: """
                    \(actor) blocked on \(subject) and never ran again. Nothing \
                    in the trace can unblock it: whoever was supposed to meet it \
                    there had already finished.
                    """
                )
            )
        }

        if runtimeStderr.lowercased().contains("all goroutines are asleep") {
            diagnoses.append(
                ConcurrencyDiagnosis(
                    conceptTag: GoConcept.deadlock,
                    headline: "Every goroutine is asleep",
                    detail: """
                    The runtime stopped the program because no goroutine could \
                    make progress. This is the runtime's own report, not the \
                    lab's inference.
                    """
                )
            )
        }

        return diagnoses
    }
}
