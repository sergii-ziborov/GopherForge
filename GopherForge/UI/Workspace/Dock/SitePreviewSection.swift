import SwiftUI
import SafariServices
import WebKit

/// The project's preview, either a local site or the isolated frontend viewer.
struct SitePreviewSection: View {
    let url: URL
    var generation: Int = 0
    var offlineFiles: [String: String]?
    @State private var showingBrowser = false

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

            Button {
                showingBrowser = true
            } label: {
                Label("Open full screen", systemImage: "safari")
                    .font(.caption.weight(.semibold))
            }
            .sheet(isPresented: $showingBrowser) {
                if let offlineFiles {
                    NavigationStack {
                        OfflineFrontendWebView(url: url, generation: generation, files: offlineFiles)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingBrowser = false } } }
                    }
                } else { SiteBrowserView(url: url) }
            }

            Group {
                if let offlineFiles { OfflineFrontendWebView(url: url, generation: generation, files: offlineFiles) }
                else { SiteWebView(url: url, generation: generation) }
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
                 : "Generated React/JS assets and local JSON only. No network or TCP listener. Temporary preview storage. Go routes are checked separately.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
