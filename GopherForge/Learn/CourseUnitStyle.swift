import SwiftUI

/// A colour and a symbol per unit.
///
/// Not decoration for its own sake: six grey rows of text are hard to tell
/// apart at a glance, and a course someone returns to daily is exactly the
/// place where "which one was that" should be answered by shape and colour
/// before it is answered by reading.
///
/// The seven tints are drawn from Go's own palette rather than from the system
/// rainbow, so the course reads as one product. Two of them are derived: the
/// unit blue is the blue golang.org used for years, and the module amber is
/// Go's yellow darkened until a word can sit on it.
enum CourseUnitStyle {
    static func symbol(for unitID: String) -> String {
        switch unitID {
        case "core": "square.stack.3d.up"
        case "structs": "cube"
        case "generics": "curlybraces"
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
        case "core": GopherForgeTheme.gopherBlue
        case "structs": GopherForgeTheme.deepBlue
        case "generics": Color(hex: 0x6B4FA8)
        case "collections": GopherForgeTheme.aqua
        case "interfaces": Color(hex: 0x375EAB)
        case "errors": GopherForgeTheme.berry
        case "modules": Color(hex: 0xB07B00)
        case "concurrency": GopherForgeTheme.sky
        case "stdlib": Color(hex: 0x4E8F3E)
        default: GopherForgeTheme.slate
        }
    }

    /// A soft wash rather than a solid block: the card carries text, and text
    /// on a saturated background is harder to read for everyone.
    static func gradient(for unitID: String) -> [Color] {
        let tint = tint(for: unitID)
        return [tint.opacity(0.22), tint.opacity(0.06)]
    }
}
