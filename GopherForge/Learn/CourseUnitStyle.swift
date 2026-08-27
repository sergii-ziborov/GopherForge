import SwiftUI

/// A colour and a symbol per unit.
///
/// Not decoration for its own sake: six grey rows of text are hard to tell
/// apart at a glance, and a course someone returns to daily is exactly the
/// place where "which one was that" should be answered by shape and colour
/// before it is answered by reading.
enum CourseUnitStyle {
    static func symbol(for unitID: String) -> String {
        switch unitID {
        case "core": "square.stack.3d.up"
        case "collections": "square.grid.3x3"
        case "interfaces": "puzzlepiece"
        case "errors": "exclamationmark.triangle"
        case "modules": "shippingbox"
        case "concurrency": "arrow.triangle.branch"
        case "stdlib": "books.vertical"
        default: "book"
        }
    }

    /// The tint a unit is recognised by.
    static func tint(for unitID: String) -> Color {
        switch unitID {
        case "core": .orange
        case "collections": .teal
        case "interfaces": .purple
        case "errors": .pink
        case "modules": .indigo
        case "concurrency": .blue
        case "stdlib": .green
        default: GopherForgeTheme.anvil
        }
    }

    /// A soft wash rather than a solid block: the card carries text, and text
    /// on a saturated background is harder to read for everyone.
    static func gradient(for unitID: String) -> [Color] {
        let tint = tint(for: unitID)
        return [tint.opacity(0.22), tint.opacity(0.06)]
    }
}
