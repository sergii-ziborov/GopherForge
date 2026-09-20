import Foundation

/// Tiny websites with Gin-compatible route exercises and live HTML, CSS and
/// JavaScript served by the app on localhost as soon as a project opens.
enum GoExampleLibrarySites {
    static let all: [GoExample] = [
        GoExampleProjectGinCafe.cafe,
        GoExampleProjectGinNotes.notes,
        GoExampleProjectGinShop.shop,
    ]
}
