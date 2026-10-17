import UIKit
import UniformTypeIdentifiers

/// The share sheet target.
///
/// It validates the URL, queues it and says so. It never tries to open the host
/// app: an extension cannot do that reliably, and pretending otherwise produces
/// a share action that silently does nothing.
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        Task { await handleSharedItem() }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.text = "Reading the shared link…"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func handleSharedItem() async {
        guard let rawURL = await firstGitHubURL() else {
            finish(message: "That share did not include a github.com repository link.")
            return
        }

        do {
            let reference = try SharedImportQueue.enqueue(rawURL)
            openHostApp(reference, rawURL: rawURL)
        } catch {
            finish(message: error.localizedDescription)
        }
    }

    /// Opens GopherForge on the queued repository. The share sheet cannot
    /// import the code itself; the app does that as soon as it is in front.
    private func openHostApp(_ reference: GitHubRepositoryReference, rawURL: String) {
        guard let url = GopherForgeLink.importURL(repository: rawURL) else {
            finish(message: "Queued \(reference.displayName). Open GopherForge to import it.")
            return
        }
        statusLabel.text = "Opening \(reference.displayName)…"
        extensionContext?.open(url) { [weak self] accepted in
            DispatchQueue.main.async {
                let message = accepted
                    ? "Opening \(reference.displayName) in GopherForge."
                    : "Queued \(reference.displayName). Open GopherForge to import it."
                self?.finish(message: message)
            }
        }
    }

    private func firstGitHubURL() async -> String? {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let types = [UTType.url, .plainText, .text, .utf8PlainText].map(\.identifier)
        for item in items {
            for provider in item.attachments ?? [] {
                for type in types {
                    guard let raw = await load(type, from: provider) else { continue }
                    if (try? GitHubRepositoryReference.parse(raw)) != nil { return raw }
                }
            }
        }
        return nil
    }

    private func load(_ typeIdentifier: String, from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier) { value, _ in
                switch value {
                case let url as URL: continuation.resume(returning: url.absoluteString)
                case let text as String: continuation.resume(returning: text)
                case let data as Data: continuation.resume(returning: String(data: data, encoding: .utf8))
                default: continuation.resume(returning: nil)
                }
            }
        }
    }

    private func finish(message: String) {
        statusLabel.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
