import SwiftUI

@main
struct GopherForgeApp: App {
    /// Applied at the scene root so every sheet, popover and alert inherits it.
    /// Setting it lower down leaves presented content following the system
    /// while the app behind it does not, which looks like a bug.
    @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode.stored(appearance).colorScheme)
        }
    }
}
