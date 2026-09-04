import Foundation

/// A symbol per lesson, chosen by what the lesson is about.
///
/// It used to be chosen by whether the lesson needed the compiler, which is two
/// symbols for forty-nine lessons — and since most lessons are compile lessons,
/// a unit was a column of identical hammers. A symbol that is the same on every
/// row is not a symbol, it is decoration, and it costs the one thing an icon is
/// there for: telling two rows apart at a glance.
///
/// The concept tag is the right key because it is the vocabulary the whole
/// product already shares with the compiler and the review queue, so a lesson
/// about closing channels looks the same wherever it appears.
enum LessonSymbol {
    static func symbol(for lesson: Lesson) -> String {
        for tag in lesson.conceptTags {
            if let symbol = byConcept[tag] { return symbol }
        }
        // Nothing recognised: fall back to the shape of the task, which at
        // least separates reading from building.
        return lesson.requiresCompiler ? "hammer" : "text.book.closed"
    }

    /// One symbol per concept the course teaches.
    static let byConcept: [String: String] = [
        GoConcept.varsUnused: "trash",
        GoConcept.shortDeclaration: "equal.square",
        GoConcept.unusedImport: "shippingbox",
        GoConcept.undefinedSymbol: "questionmark.circle",
        GoConcept.importPath: "arrow.triangle.branch",
        GoConcept.missingReturn: "arrow.uturn.left",
        GoConcept.typeAssignment: "arrow.left.arrow.right",

        GoConcept.sliceCapacity: "ruler",
        GoConcept.sliceBounds: "arrow.left.and.right.square",
        GoConcept.sliceAliasing: "link",
        GoConcept.mapZeroValue: "square.grid.3x3",
        GoConcept.mapOrder: "shuffle",
        GoConcept.stringRunes: "textformat",
        GoConcept.stringsBuilder: "text.alignleft",

        GoConcept.methodSet: "function",
        GoConcept.nilInterface: "circle.slash",
        GoConcept.smallInterface: "puzzlepiece",
        GoConcept.typeAssertion: "questionmark.diamond",
        GoConcept.embedding: "square.stack.3d.down.right",

        GoConcept.explicitErrorCheck: "exclamationmark.triangle",
        GoConcept.errorWrapping: "shippingbox.and.arrow.backward",
        GoConcept.errorSentinel: "flag",
        GoConcept.deferCleanup: "clock.arrow.circlepath",
        GoConcept.customError: "exclamationmark.bubble",
        GoConcept.panicIsNotAnError: "bolt.trianglebadge.exclamationmark",

        GoConcept.packageInit: "power",

        GoConcept.deadlock: "lock",
        GoConcept.channelClose: "xmark.circle",
        GoConcept.channelDirection: "arrow.right.circle",
        GoConcept.selectBranch: "arrow.triangle.pull",
        GoConcept.contextCancel: "nosign",
        GoConcept.contextFirstParameter: "list.number",
        GoConcept.goroutineLeak: "drop",
        GoConcept.waitGroup: "person.3",
        GoConcept.mutex: "lock.shield",

        GoConcept.constants: "number",
        GoConcept.switchNoFallthrough: "arrow.triangle.swap",
        GoConcept.conversion: "arrow.2.squarepath",

        GoConcept.structLiteral: "cube",
        GoConcept.pointerReceiver: "arrow.up.forward.square",
        GoConcept.closure: "curlybraces.square",

        GoConcept.typeParameter: "chevron.left.forwardslash.chevron.right",
        GoConcept.rangeOverFunc: "arrow.trianglehead.clockwise",
        GoConcept.genericMethod: "point.forward.to.point.capsulepath",
        GoConcept.constraint: "line.3.horizontal.decrease",
        GoConcept.genericsOveruse: "exclamationmark.questionmark",

        GoConcept.stdlibTime: "clock",
        GoConcept.stdlibSort: "arrow.up.arrow.down",
        GoConcept.stdlibIO: "arrow.left.arrow.right.circle",
        GoConcept.stdlibJSON: "doc.text",
        GoConcept.stdlibTesting: "checkmark.seal",
        GoConcept.stdlibHTTP: "network",
        GoConcept.stdlibImage: "photo",
        GoConcept.stdlibStrconv: "textformat.123",
    ]
}
