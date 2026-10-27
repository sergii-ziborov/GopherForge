import SwiftUI
import WebKit

/// WebKit's content process sees only this origin's generated assets and JSON.
struct OfflineFrontendWebView: UIViewRepresentable {
    let url: URL
    let generation: Int
    let files: [String: String]

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, generation: generation, files: files)
    }

    func makeUIView(context: Context) -> Container {
        let container = Container()
        let coordinator = context.coordinator
        container.loadTask = Task { @MainActor [weak container] in
            do {
                // Install every policy before WebKit copies the configuration.
                let view = try await Self.makeWebView(coordinator: coordinator)
                guard !Task.isCancelled, let container else { return }
                container.install(view)
                coordinator.ready = true
                view.load(URLRequest(url: coordinator.url))
            } catch {
                guard !Task.isCancelled else { return }
                container?.showFailure()
            }
        }
        return container
    }

    @MainActor
    static func makeWebView(coordinator: Coordinator) async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(coordinator.handler, forURLScheme: OfflinePreviewResources.scheme)
        try await OfflinePreviewPolicy.apply(to: configuration)
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = coordinator
        view.isOpaque = false
        return view
    }

    func updateUIView(_ container: Container, context: Context) {
        let coordinator = context.coordinator
        if coordinator.url != url || coordinator.generation != generation {
            coordinator.url = url
            coordinator.generation = generation
            coordinator.handler.resources = OfflinePreviewResources(url: url, files: files)
            if coordinator.ready { container.webView?.load(URLRequest(url: url)) }
        }
    }

    static func dismantleUIView(_ container: Container, coordinator: Coordinator) {
        container.loadTask?.cancel()
        container.webView?.stopLoading()
        container.webView?.navigationDelegate = nil
    }

    @MainActor
    final class Container: UIView {
        var webView: WKWebView?
        var loadTask: Task<Void, Never>?

        func install(_ view: WKWebView) {
            webView = view
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        func showFailure() {
            let label = UILabel()
            label.text = "Offline preview policy could not load. No project was opened."
            label.numberOfLines = 0
            label.frame = bounds.insetBy(dx: 12, dy: 12)
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(label)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var url: URL
        var generation: Int
        var ready = false
        let handler: OfflinePreviewSchemeHandler

        init(url: URL, generation: Int, files: [String: String]) {
            self.url = url
            self.generation = generation
            handler = OfflinePreviewSchemeHandler(resources: OfflinePreviewResources(url: url, files: files))
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            let candidate = navigationAction.request.url
            let allowed = candidate?.scheme == OfflinePreviewResources.scheme && candidate?.host == url.host
                && navigationAction.targetFrame?.isMainFrame == true
            return allowed ? .allow : .cancel
        }
    }
}
