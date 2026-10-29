import SwiftUI
import SafariServices
import WebKit

/// The project's preview, either a local site or the isolated frontend viewer.
struct SitePreviewSection: View {
    let url: URL
    var generation: Int = 0
    var offlineFiles: [String: String]?
    var project: GopherForgeProject?
    @Environment(\.openURL) private var openURL
    @State private var reloadGeneration = 0
    @State private var showingBrowser = false
    @State private var goBackend: OfflineGoBackend?

    init(url: URL, generation: Int = 0, offlineFiles: [String: String]? = nil, project: GopherForgeProject? = nil) {
        self.url = url
        self.generation = generation
        self.offlineFiles = offlineFiles
        self.project = project
        if let files = offlineFiles, let data = files[OfflineFrontendRecipe.path]?.data(using: .utf8),
           let recipe = try? JSONDecoder().decode(OfflineFrontendRecipe.self, from: data), recipe.backend == "gin-replay" {
            _goBackend = State(initialValue: OfflineGoBackend(files: files, paths: recipe.backendPaths))
        } else { _goBackend = State(initialValue: nil) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(offlineFiles == nil ? "Site on this device" : "Isolated offline preview", systemImage: offlineFiles == nil ? "globe" : "network.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.outputSitePreview)

            if offlineFiles == nil {
                Text(url.absoluteString)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier(AccessibilityID.outputSite)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { previewActions }
                VStack(alignment: .leading, spacing: 12) { previewActions }
            }
            .font(.callout)
            .sheet(isPresented: $showingBrowser) {
                if let offlineFiles {
                    NavigationStack {
                        OfflineFrontendWebView(url: url, generation: generation + reloadGeneration, files: offlineFiles, backend: goBackend, accessibilityID: "offline.preview.fullscreen")
                            .navigationTitle("Web preview")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) { Button("Done") { showingBrowser = false } }
                                ToolbarItem(placement: .bottomBar) { shareAction }
                            }
                    }
                } else { SiteBrowserView(url: url) }
            }

            Group {
                if let offlineFiles { OfflineFrontendWebView(url: url, generation: generation + reloadGeneration, files: offlineFiles, backend: goBackend) }
                else { SiteWebView(url: url, generation: generation + reloadGeneration) }
            }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                )

            Text(offlineFiles == nil
                 ? "Go checks the Gin routes without opening a port. The app serves this project's web files on this device."
                 : goBackend != nil
                    ? "Local Go handlers, no network port. Temporary teaching API: up to 64 changes, replayed between requests. Rebuilding resets its state."
                    : "Generated React/JS assets and local JSON only. No network or TCP listener. Temporary preview storage. Go routes are checked separately.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(offlineFiles == nil
                 ? "This address works only on this device while its preview is running. iOS may suspend it when you switch apps. Share the project for someone else to open."
                 : "This isolated preview opens inside GopherForge. Share the project archive for someone else to open; it has no public web address.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var previewActions: some View {
        Button { showingBrowser = true } label: {
            Label("Open full screen", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .accessibilityIdentifier("preview.fullscreen")
        Button { reloadGeneration += 1 } label: {
            Label("Reload", systemImage: "arrow.clockwise")
        }
        .accessibilityIdentifier("preview.reload")
        Menu {
            if offlineFiles == nil {
                Button { openURL(url) } label: { Label("Open in Browser", systemImage: "safari") }
                    .accessibilityIdentifier("preview.externalBrowser")
                ShareLink(item: url, message: Text("Local GopherForge preview — this address works only on the device running the project.")) {
                    Label("Share local address", systemImage: "link")
                }
                .accessibilityIdentifier("preview.shareLocalAddress")
            }
            shareAction
        } label: { Label("Share / Open", systemImage: "square.and.arrow.up") }
        .accessibilityIdentifier("preview.actions")
    }

    @ViewBuilder private var shareAction: some View {
        if let project {
            ShareLink(item: ProjectExport(project: project), preview: SharePreview(project.name)) {
                Label("Share project…", systemImage: "shippingbox")
            }
            .accessibilityIdentifier("preview.shareProject")
        }
    }
}

/// Keeps the app in the foreground while its loopback server is in use.
private struct SiteBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// A page, not a screenshot of one.
struct SiteWebView: UIViewRepresentable {
    let url: URL
    var generation: Int = 0

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.isOpaque = false
        view.backgroundColor = .secondarySystemBackground
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.url != url || context.coordinator.generation != generation {
            context.coordinator.url = url
            context.coordinator.generation = generation
            view.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, generation: generation)
    }

    final class Coordinator {
        var url: URL
        var generation: Int
        init(url: URL, generation: Int) {
            self.url = url
            self.generation = generation
        }
    }
}
