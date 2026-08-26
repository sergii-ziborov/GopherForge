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
        guard let rawURL = await firstSharedURL() else {
            finish(message: "GopherForge could not find a link to import.")
            return
        }

        do {
            let reference = try SharedImportQueue.enqueue(rawURL)
            finish(message: "Queued \(reference.displayName). Open GopherForge to import it.")
        } catch {
            finish(message: error.localizedDescription)
        }
    }

    private func firstSharedURL() async -> String? {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            for provider in item.attachments ?? [] {
                if let url = await load(UTType.url.identifier, from: provider) { return url }
                if let text = await load(UTType.plainText.identifier, from: provider) { return text }
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
