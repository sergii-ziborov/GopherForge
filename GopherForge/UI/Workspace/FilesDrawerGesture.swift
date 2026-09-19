import SwiftUI
import UIKit

/// The leading-edge swipe that opens the phone Files drawer.
///
/// A button still exists, but a drawer that only a toolbar hit can open is
/// a drawer people miss. The gesture is the same shape as every other iOS
/// sidebar: start near the left edge and travel right, more horizontally
/// than vertically so an editor scroll does not open the tree.
enum FilesDrawerGesture {
    static let edgeWidth: CGFloat = 72
    static let minimumTranslation: CGFloat = 48

    static func shouldOpen(startX: CGFloat, translation: CGSize) -> Bool {
        startX <= edgeWidth
            && translation.width >= minimumTranslation
            && translation.width > abs(translation.height)
    }

    static func shouldOpen(startX: CGFloat, translationWidth: CGFloat) -> Bool {
        shouldOpen(startX: startX, translation: CGSize(width: translationWidth, height: 0))
    }

    static func shouldClose(translation: CGSize) -> Bool {
        translation.width <= -minimumTranslation
            && abs(translation.width) > abs(translation.height)
    }

    static func shouldClose(translationWidth: CGFloat) -> Bool {
        shouldClose(translation: CGSize(width: translationWidth, height: 0))
    }
}

/// Installs a system screen-edge pan on the hosting view.
///
/// A clear overlay that owns the leading 28 pt steals taps from the first
/// column of code. The system edge gesture does not: taps still reach the
/// editor, and a left-to-right flick still opens Files.
struct LeadingEdgeOpenGesture: UIViewRepresentable {
    var onOpen: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpen: onOpen)
    }

    func makeUIView(context: Context) -> InstallerView {
        InstallerView(coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.onOpen = onOpen
        uiView.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var onOpen: () -> Void

        init(onOpen: @escaping () -> Void) {
            self.onOpen = onOpen
        }

        @objc func recognized(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let translation = gesture.translation(in: gesture.view)
            if FilesDrawerGesture.shouldOpen(
                startX: 0,
                translation: CGSize(width: translation.x, height: translation.y)
            ) {
                onOpen()
            }
        }
    }

    final class InstallerView: UIView {
        var coordinator: Coordinator
        private weak var host: UIView?
        private var installed: UIScreenEdgePanGestureRecognizer?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfNeeded()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            installIfNeeded()
        }

        private func installIfNeeded() {
            guard let host = superview else { return }
            if host === self.host, installed != nil { return }
            if let installed {
                self.host?.removeGestureRecognizer(installed)
            }
            let gesture = UIScreenEdgePanGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.recognized)
            )
            gesture.edges = .left
            host.addGestureRecognizer(gesture)
            self.host = host
            installed = gesture
        }

        deinit {
            if let installed {
                host?.removeGestureRecognizer(installed)
            }
        }
    }
}
