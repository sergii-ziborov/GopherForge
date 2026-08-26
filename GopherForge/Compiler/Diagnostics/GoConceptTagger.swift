import Foundation

/// Maps a toolchain message to a curated concept tag used by the review
/// scheduler and the idiom coach.
///
/// The set is deliberately small. A tag is assigned only when the wording has
/// been stable across Go releases long enough to teach against; anything else
/// stays untagged rather than producing a lesson the compiler may stop
/// justifying after an upgrade.
enum GoConceptTagger {
    private static let rules: [(needle: String, tag: String, anchored: Bool)] = [
        ("declared and not used", GoConcept.varsUnused, true),
        ("imported and not used", GoConcept.unusedImport, true),
        ("undefined:", GoConcept.undefinedSymbol, true),
        ("missing return", GoConcept.missingReturn, false),
        ("no new variables on left side", GoConcept.shortDeclaration, false),
        ("assignment mismatch", GoConcept.explicitErrorCheck, false),
        ("does not implement", GoConcept.methodSet, false),
        ("cannot use", GoConcept.typeAssignment, false),
        ("all goroutines are asleep", GoConcept.deadlock, false),
        ("send on closed channel", GoConcept.channelClose, false),
        ("close of closed channel", GoConcept.channelClose, false),
        ("nil map", GoConcept.mapZeroValue, false),
        ("index out of range", GoConcept.sliceBounds, false),
        ("invalid memory address or nil pointer", GoConcept.nilInterface, false),
    ]

    static func tag(for message: String) -> String? {
        let lowered = message.lowercased()
        for rule in rules {
            let matched = rule.anchored ? lowered.hasPrefix(rule.needle) : lowered.contains(rule.needle)
            if matched { return rule.tag }
        }
        return nil
    }
}
