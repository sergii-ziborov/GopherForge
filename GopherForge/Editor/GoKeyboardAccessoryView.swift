import UIKit

/// The row above the keyboard.
///
/// Three fixed regions, because a row that only scrolls loses the two controls
/// people reach for most: suggestions on the left, the symbols Go needs in a
/// scrolling middle, and a way to put the keyboard away on the right. Without
/// that last one an iPhone editor is a trap — the keyboard covers half the file
/// and nothing on screen dismisses it.
final class GoKeyboardAccessoryView: UIView {
    /// Characters iOS buries but Go needs constantly. Ordered by how often they
    /// are typed rather than alphabetically.
    private static let symbols = [
        "\t", ":=", "<-", "{", "}", "(", ")", "[", "]",
        "*", "&", "!=", "==", ":", ";", "_", "...", "\"", "`", "%",
    ]

    private let onInsert: (String) -> Void
    private let onDismiss: () -> Void
    private let suggestions: () -> [GoCompletionSuggestion]

    init(
        onInsert: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void,
        suggestions: @escaping () -> [GoCompletionSuggestion]
    ) {
        self.onInsert = onInsert
        self.onDismiss = onDismiss
        self.suggestions = suggestions
        super.init(frame: .zero)

        backgroundColor = .secondarySystemBackground
        autoresizingMask = .flexibleHeight

        let completeButton = makeCompletionButton()
        let dismissButton = makeDismissButton()
        let scrollView = makeSymbolScrollView()
        let leadingSeparator = makeSeparator()
        let trailingSeparator = makeSeparator()

        addSubview(completeButton)
        addSubview(leadingSeparator)
        addSubview(scrollView)
        addSubview(trailingSeparator)
        addSubview(dismissButton)

        NSLayoutConstraint.activate(
            layout(
                complete: completeButton,
                leadingSeparator: leadingSeparator,
                scrollView: scrollView,
                trailingSeparator: trailingSeparator,
                dismiss: dismissButton
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Controls

    /// Suggestions are offered as a menu rather than inserted on tap. Nothing
    /// reaches the buffer without the user choosing it.
    private func makeCompletionButton() -> UIButton {
        let button = Self.accessoryButton(
            title: nil,
            systemImage: "text.badge.plus",
            tint: .systemOrange,
            accessibilityLabel: "Suggest Go code"
        )
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else { return completion([]) }
                let items = suggestions().map { suggestion in
                    UIAction(
                        title: suggestion.title,
                        subtitle: suggestion.detail
                    ) { [weak self] _ in
                        self?.onInsert(suggestion.insertion)
                    }
                }
                completion(items.isEmpty ? [Self.emptySuggestionAction()] : items)
            }
        ])
        return button
    }

    private static func emptySuggestionAction() -> UIAction {
        let action = UIAction(title: "Nothing to suggest here") { _ in }
        action.attributes = .disabled
        return action
    }

    private func makeDismissButton() -> UIButton {
        let button = Self.accessoryButton(
            title: nil,
            systemImage: "keyboard.chevron.compact.down",
            tint: .systemOrange,
            accessibilityLabel: "Hide keyboard"
        )
        button.accessibilityIdentifier = "editor.hideKeyboard"
        button.addAction(UIAction { [weak self] _ in self?.onDismiss() }, for: .touchUpInside)
        return button
    }

    private func makeSymbolScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        for symbol in Self.symbols {
            let button = Self.accessoryButton(
                title: symbol == "\t" ? "⇥" : symbol,
                systemImage: nil,
                tint: .label,
                accessibilityLabel: symbol == "\t" ? "Tab" : symbol
            )
            button.addAction(UIAction { [weak self] _ in self?.onInsert(symbol) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
        return scrollView
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }

    // MARK: - Layout

    private func layout(
        complete: UIButton,
        leadingSeparator: UIView,
        scrollView: UIScrollView,
        trailingSeparator: UIView,
        dismiss: UIButton
    ) -> [NSLayoutConstraint] {
        [
            heightAnchor.constraint(equalToConstant: 46),

            complete.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            complete.centerYAnchor.constraint(equalTo: centerYAnchor),
            complete.heightAnchor.constraint(equalToConstant: 36),
            complete.widthAnchor.constraint(equalToConstant: 42),

            leadingSeparator.leadingAnchor.constraint(equalTo: complete.trailingAnchor, constant: 5),
            leadingSeparator.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            leadingSeparator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            leadingSeparator.widthAnchor.constraint(equalToConstant: 1),

            dismiss.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            dismiss.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismiss.heightAnchor.constraint(equalToConstant: 36),
            dismiss.widthAnchor.constraint(equalToConstant: 42),

            trailingSeparator.trailingAnchor.constraint(equalTo: dismiss.leadingAnchor, constant: -5),
            trailingSeparator.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            trailingSeparator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            trailingSeparator.widthAnchor.constraint(equalToConstant: 1),

            scrollView.leadingAnchor.constraint(equalTo: leadingSeparator.trailingAnchor, constant: 5),
            scrollView.trailingAnchor.constraint(equalTo: trailingSeparator.leadingAnchor, constant: -5),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
    }

    private static func accessoryButton(
        title: String?,
        systemImage: String?,
        tint: UIColor,
        accessibilityLabel: String? = nil
    ) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = systemImage.flatMap { UIImage(systemName: $0) }
        configuration.imagePadding = 4
        configuration.baseForegroundColor = tint
        configuration.cornerStyle = .small
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9)
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        button.accessibilityLabel = accessibilityLabel ?? title
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
