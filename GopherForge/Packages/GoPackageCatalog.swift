import Foundation

/// A starting point for browsing, because Go has no package search API.
///
/// This is worth stating plainly rather than papering over: `proxy.golang.org`
/// resolves a module path you already know, and `pkg.go.dev` has search but no
/// API behind it. So the app does two things instead of pretending to search:
/// it resolves any module path typed in full, and it offers this list of
/// modules that are widely used in the kind of program this app builds.
///
/// Nothing here is ranked by the app. The numbers a user sees come from
/// deps.dev at the moment they look.
enum GoPackageCatalog {
    struct Entry: Identifiable, Equatable, Sendable {
        let path: String
        /// One line, for browsing. What deps.dev returns is shown alongside it.
        let blurb: String
        let category: String

        var id: String { path }
    }

    static let entries: [Entry] = [
        Entry(
            path: "github.com/google/uuid",
            blurb: "Generate and parse UUIDs",
            category: "Identifiers"
        ),
        Entry(
            path: "github.com/stretchr/testify",
            blurb: "Assertions and mocks for tests",
            category: "Testing"
        ),
        Entry(
            path: "github.com/google/go-cmp",
            blurb: "Compare values in tests, with readable diffs",
            category: "Testing"
        ),
        Entry(
            path: "github.com/spf13/cobra",
            blurb: "Commands, flags and help for a CLI",
            category: "Command line"
        ),
        Entry(
            path: "github.com/urfave/cli",
            blurb: "A smaller way to build a CLI",
            category: "Command line"
        ),
        Entry(
            path: "github.com/pkg/errors",
            blurb: "Error wrapping, from before %w existed",
            category: "Errors"
        ),
        Entry(
            path: "github.com/json-iterator/go",
            blurb: "A drop-in, faster encoding/json",
            category: "Encoding"
        ),
        Entry(
            path: "gopkg.in/yaml.v3",
            blurb: "Read and write YAML",
            category: "Encoding"
        ),
        Entry(
            path: "github.com/go-chi/chi",
            blurb: "An HTTP router that stays close to net/http",
            category: "HTTP"
        ),
        Entry(
            path: "github.com/gorilla/mux",
            blurb: "A long-standing HTTP router",
            category: "HTTP"
        ),
        Entry(
            path: "golang.org/x/sync",
            blurb: "errgroup, semaphore and friends",
            category: "Concurrency"
        ),
        Entry(
            path: "golang.org/x/text",
            blurb: "Unicode, language tags and transforms",
            category: "Text"
        ),
    ]

    static var categories: [String] {
        var seen: Set<String> = []
        return entries.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    static func entries(in category: String) -> [Entry] {
        entries.filter { $0.category == category }
    }

    /// Substring match over path and blurb. Local, instant, and honest about
    /// being a filter over a list rather than a search of the ecosystem.
    static func filtered(by query: String) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.path.lowercased().contains(trimmed) || $0.blurb.lowercased().contains(trimmed)
        }
    }

    /// True when the text looks like a module path the proxy could resolve, so
    /// the UI can offer "look this up" for something not in the list.
    static func looksLikeModulePath(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: "/")
        return parts.count >= 2 && parts[0].contains(".") && !trimmed.contains(" ")
    }
}
