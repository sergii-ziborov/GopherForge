import Foundation

/// The bundled notices, split the way a reviewer reads a Third-Party Library
/// screen: one family, then the components that belong to it.
///
/// Parsed from `ThirdPartyNotices.md` rather than retyped, so a licence that
/// moves in the file moves here too.
enum ThirdPartyLibrary {
    struct Family: Equatable, Identifiable {
        var id: String { heading }
        var heading: String
        var blurb: String
        var components: [Component]
    }

    struct Component: Equatable, Identifiable {
        var id: String { name }
        var name: String
        var licence: String
        var summary: String
    }

    static func families(in text: String) -> [Family] {
        text.components(separatedBy: "\n## ")
            .dropFirst()
            .map(parseFamily)
            .filter { !$0.heading.isEmpty }
    }

    private static func parseFamily(_ chunk: String) -> Family {
        let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let heading = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rest = lines.dropFirst().joined(separator: "\n")
        let parts = rest.components(separatedBy: "\n### ")
        let blurb = collapse(parts.first ?? "")
        let components = parts.dropFirst().map(parseComponent)
        return Family(heading: heading, blurb: blurb, components: components)
    }

    private static func parseComponent(_ chunk: String) -> Component {
        let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let name = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = lines.dropFirst().joined(separator: "\n")
        return Component(
            name: name,
            licence: licence(in: body),
            summary: firstParagraph(in: body)
        )
    }

    private static func licence(in body: String) -> String {
        let markers = [
            "**BSD 3-Clause License.**",
            "**MIT License.**",
            "**Apache License 2.0 with Runtime Library Exception.**",
            "**unknown**",
        ]
        for marker in markers where body.contains(marker) {
            return marker
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        return "Their own terms"
    }

    private static func firstParagraph(in body: String) -> String {
        let stripped = body
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let blocks = stripped.components(separatedBy: "\n\n")
        return collapse(blocks.first { !$0.hasPrefix("Copyright") && !$0.hasPrefix("<http") } ?? "")
    }

    private static func collapse(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
