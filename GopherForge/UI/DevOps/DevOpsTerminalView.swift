import SwiftUI
import UIKit

/// The terminal's own palette. A terminal is dark in both appearances, as the
/// ones learners will meet at work are, so the colours here are fixed.
enum DevOpsTerminalStyle {
    static let background = Color(hex: 0x0B141C)
    static let surface = Color(hex: 0x13202B)
    static let text = Color(hex: 0xE3EAF0)
    static let dim = Color(hex: 0x7F8C98)
    static let path = Color(hex: 0x5DC9E2)
    static let prompt = Color(hex: 0x3FD08F)
    static let error = Color(hex: 0xFF7B72)
    static let directory = Color(hex: 0x58A6FF)
    static let script = Color(hex: 0x3FD08F)
    static let uiBackground = UIColor(red: 0x0B / 255, green: 0x14 / 255, blue: 0x1C / 255, alpha: 1)
    /// Smaller on a phone, where columns are scarcer than pixels.
    @MainActor static var defaultFontSize: Double { UIDevice.current.userInterfaceIdiom == .pad ? 15 : 13 }

    /// The sixteen ANSI colours, for scripts that print `\e[32m` and friends.
    static let ansi: [Color] = [
        Color(hex: 0x484F58), Color(hex: 0xFF7B72), Color(hex: 0x3FB950), Color(hex: 0xD29922),
        Color(hex: 0x58A6FF), Color(hex: 0xBC8CFF), Color(hex: 0x39C5CF), Color(hex: 0xB1BAC4),
        Color(hex: 0x6E7681), Color(hex: 0xFFA198), Color(hex: 0x56D364), Color(hex: 0xE3B341),
        Color(hex: 0x79C0FF), Color(hex: 0xD2A8FF), Color(hex: 0x56D4DD), Color(hex: 0xF0F6FC),
    ]

    /// Renders text with its ANSI SGR colour codes applied and every other
    /// escape sequence removed.
    static func attributed(_ text: String, base: Color) -> AttributedString {
        var out = AttributedString()
        var color: Color?
        var bold = false, dim = false, italic = false, underline = false
        var run = ""
        func flush() {
            guard !run.isEmpty else { return }
            var piece = AttributedString(run)
            piece.foregroundColor = dim ? (color ?? base).opacity(0.6) : (color ?? base)
            if bold { piece.inlinePresentationIntent = .stronglyEmphasized }
            if italic { piece.inlinePresentationIntent = (piece.inlinePresentationIntent ?? []).union(.emphasized) }
            if underline { piece.underlineStyle = .single }
            out += piece
            run = ""
        }
        var scalars = Array(text.unicodeScalars)[...]
        while let scalar = scalars.popFirst() {
            guard scalar == "\u{1b}" else {
                run.unicodeScalars.append(scalar)
                continue
            }
            guard scalars.first == "[" else { continue }
            scalars.removeFirst()
            var parameters = ""
            while let next = scalars.first, !(0x40...0x7E).contains(next.value) {
                parameters.unicodeScalars.append(next)
                scalars.removeFirst()
            }
            guard let final = scalars.popFirst(), final == "m" else { continue }
            flush()
            var codes = parameters.split(separator: ";").compactMap { Int($0) }[...]
            if codes.isEmpty { codes = [0] }
            while let code = codes.popFirst() {
                switch code {
                case 0: color = nil; bold = false; dim = false; italic = false; underline = false
                case 1: bold = true
                case 2: dim = true
                case 3: italic = true
                case 4: underline = true
                case 22: bold = false; dim = false
                case 23: italic = false
                case 24: underline = false
                case 30...37: color = ansi[code - 30]
                case 90...97: color = ansi[code - 90 + 8]
                case 39: color = nil
                case 38:
                    if codes.first == 5, codes.count >= 2 {
                        codes.removeFirst()
                        let index = codes.removeFirst()
                        color = index < 16 ? ansi[index] : nil
                    } else if codes.first == 2, codes.count >= 4 {
                        codes.removeFirst()
                        let r = codes.removeFirst(), g = codes.removeFirst(), b = codes.removeFirst()
                        color = Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
                    }
                default: break
                }
            }
        }
        flush()
        return out
    }

    /// `ls` and `tree` output with directories and scripts picked out, the way
    /// a terminal's colours make a listing scannable.
    static func listing(_ text: String) -> AttributedString {
        var out = AttributedString()
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            if index > 0 { out += AttributedString("\n") }
            let name = line.split(separator: " ").last.map(String.init) ?? line
            var piece = AttributedString(line)
            piece.foregroundColor = self.text
            if name.hasSuffix("/"), let range = piece.range(of: name, options: .backwards) {
                piece[range].foregroundColor = directory
                piece[range].inlinePresentationIntent = .stronglyEmphasized
            } else if name.hasSuffix(".sh"), let range = piece.range(of: name, options: .backwards) {
                piece[range].foregroundColor = script
            }
            out += piece
        }
        return out
    }
}

/// The scrolling transcript with the live prompt at its end, as in a real
/// terminal: you type where the next output will appear.
struct DevOpsTerminalView: View {
    @Bindable var session: DevOpsLabSession
    @AppStorage("devops.terminal.fontSize") private var fontSize = DevOpsTerminalStyle.defaultFontSize
    @State private var focusRequest = 1

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(session.entries) { entry in
                        DevOpsTerminalLine(entry: entry, fontSize: fontSize).id(entry.id)
                    }
                    prompt.id("prompt")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Output starts at the top, as in a terminal, and follows the
            // newest line once there is more than a screenful.
            .defaultScrollAnchor(.top, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
            .background(DevOpsTerminalStyle.background)
            .contentShape(Rectangle())
            .onTapGesture { focusRequest += 1 }
            .onChange(of: session.entries.last?.id) { scrollToPrompt(proxy) }
            .onChange(of: session.isRunning) { scrollToPrompt(proxy) }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in scrollToPrompt(proxy) }
            .accessibilityIdentifier("devops.terminal")
        }
        .environment(\.colorScheme, .dark)
    }

    private func scrollToPrompt(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("prompt", anchor: .bottom) }
    }

    private var prompt: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(promptText).font(.system(size: fontSize, design: .monospaced)).fixedSize()
            DevOpsPromptField(session: session, focusRequest: focusRequest, fontSize: fontSize)
                .frame(maxWidth: .infinity, minHeight: fontSize * 1.4)
            if session.isRunning {
                ProgressView().controlSize(.small).tint(DevOpsTerminalStyle.dim)
                    .accessibilityLabel("Running")
            }
        }
    }

    private var promptText: AttributedString {
        if session.continuation != nil {
            var more = AttributedString("> ")
            more.foregroundColor = DevOpsTerminalStyle.dim
            return more
        }
        var path = AttributedString(session.promptDirectory)
        path.foregroundColor = DevOpsTerminalStyle.path
        path.inlinePresentationIntent = .stronglyEmphasized
        var mark = AttributedString(" $ ")
        mark.foregroundColor = session.lastCommandFailed ? DevOpsTerminalStyle.error : DevOpsTerminalStyle.prompt
        return path + mark
    }
}

struct DevOpsTerminalLine: View {
    let entry: DevOpsTerminalEntry
    let fontSize: Double

    var body: some View {
        Text(content)
            .font(.system(size: fontSize, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, entry.kind == .command && !entry.continuation ? 4 : 0)
            .accessibilityIdentifier(entry.kind == .command ? "devops.command" : "devops.output")
    }

    private var content: AttributedString {
        switch entry.kind {
        case .command:
            var lead: AttributedString
            if entry.continuation {
                lead = AttributedString("> ")
                lead.foregroundColor = DevOpsTerminalStyle.dim
            } else {
                var path = AttributedString(entry.cwd)
                path.foregroundColor = DevOpsTerminalStyle.path
                path.inlinePresentationIntent = .stronglyEmphasized
                var mark = AttributedString(" $ ")
                mark.foregroundColor = (entry.status ?? 0) == 0 ? DevOpsTerminalStyle.prompt : DevOpsTerminalStyle.error
                lead = path + mark
            }
            var command = AttributedString(entry.text)
            command.foregroundColor = DevOpsTerminalStyle.text
            var line = lead + command
            if let status = entry.status, status != 0 {
                var badge = AttributedString("  ✗ \(status)")
                badge.foregroundColor = DevOpsTerminalStyle.error.opacity(0.8)
                line += badge
            }
            return line
        case .output:
            return entry.listing ? DevOpsTerminalStyle.listing(entry.text) : DevOpsTerminalStyle.attributed(entry.text, base: DevOpsTerminalStyle.text)
        case .error:
            return DevOpsTerminalStyle.attributed(entry.text, base: DevOpsTerminalStyle.error)
        case .notice:
            var notice = AttributedString(entry.text)
            notice.foregroundColor = DevOpsTerminalStyle.dim
            return notice
        }
    }
}

/// The prompt's text field. UIKit, because a terminal needs Tab, the arrow
/// keys and Ctrl-C from a hardware keyboard, a key row above the software one,
/// and none of the smart quotes and autocorrection that break shell syntax.
private struct DevOpsPromptField: UIViewRepresentable {
    @Bindable var session: DevOpsLabSession
    let focusRequest: Int
    let fontSize: Double

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeUIView(context: Context) -> PromptTextField {
        let field = PromptTextField()
        field.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        field.textColor = UIColor(DevOpsTerminalStyle.text)
        field.tintColor = UIColor(DevOpsTerminalStyle.prompt)
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.keyboardType = .asciiCapable
        field.keyboardAppearance = .dark
        field.returnKeyType = .default
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        field.accessibilityIdentifier = "devops.terminal.input"
        field.accessibilityLabel = "Command"
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.inputAccessoryView = DevOpsKeyRow(coordinator: context.coordinator)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.coordinator = context.coordinator
        context.coordinator.field = field
        return field
    }

    func updateUIView(_ field: PromptTextField, context: Context) {
        context.coordinator.session = session
        if field.text != session.input {
            field.text = session.input
            let end = field.endOfDocument
            field.selectedTextRange = field.textRange(from: end, to: end)
        }
        if field.font?.pointSize != CGFloat(fontSize) {
            field.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak field] in
                guard let field, field.window != nil, !field.isFirstResponder else { return }
                field.becomeFirstResponder()
            }
        }
    }

    static func dismantleUIView(_ field: PromptTextField, coordinator: Coordinator) {
        field.resignFirstResponder()
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var session: DevOpsLabSession
        weak var field: PromptTextField?
        var lastFocusRequest = 0

        init(session: DevOpsLabSession) { self.session = session }

        @objc func changed(_ field: UITextField) { session.input = field.text ?? "" }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            let line = textField.text ?? ""
            textField.text = ""
            session.input = ""
            session.enter(line)
            return false
        }

        /// A pasted script arrives as one string; each finished line runs in
        /// turn and the last, unfinished one stays at the prompt.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard string.contains(where: \.isNewline) else { return true }
            let current = (textField.text ?? "") as NSString
            var lines = current.replacingCharacters(in: range, with: string)
                .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                .components(separatedBy: "\n")
            let rest = lines.removeLast()
            textField.text = rest
            session.input = rest
            lines.forEach(session.enter)
            return false
        }

        func insert(_ text: String) {
            guard let field else { return }
            field.insertText(text)
            session.input = field.text ?? ""
        }
        func tab() { session.input = field?.text ?? session.input; session.complete() }
        func up() { session.historyUp() }
        func down() { session.historyDown() }
        func interrupt() { session.input = field?.text ?? session.input; session.interrupt() }
        func clear() { session.clear() }
        func clearLine() { session.input = ""; field?.text = "" }
        func move(_ offset: Int) {
            guard let field, let range = field.selectedTextRange,
                  let position = field.position(from: range.start, offset: offset) else { return }
            field.selectedTextRange = field.textRange(from: position, to: position)
        }
        func hideKeyboard() { field?.resignFirstResponder() }
    }
}

private final class PromptTextField: UITextField {
    weak var coordinator: DevOpsPromptField.Coordinator?

    override var keyCommands: [UIKeyCommand]? {
        let commands: [(String, UIKeyModifierFlags, Selector, String)] = [
            ("\t", [], #selector(tabKey), "Complete"),
            (UIKeyCommand.inputUpArrow, [], #selector(upKey), "Previous command"),
            (UIKeyCommand.inputDownArrow, [], #selector(downKey), "Next command"),
            ("c", .control, #selector(interruptKey), "Interrupt"),
            ("l", .control, #selector(clearKey), "Clear screen"),
            ("u", .control, #selector(clearLineKey), "Clear line"),
            ("k", .command, #selector(clearKey), "Clear screen"),
        ]
        return commands.map { input, flags, action, title in
            let command = UIKeyCommand(title: title, action: action, input: input, modifierFlags: flags)
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }
    @objc private func tabKey() { coordinator?.tab() }
    @objc private func upKey() { coordinator?.up() }
    @objc private func downKey() { coordinator?.down() }
    @objc private func interruptKey() { coordinator?.interrupt() }
    @objc private func clearKey() { coordinator?.clear() }
    @objc private func clearLineKey() { coordinator?.clearLine() }
}

/// The row of keys a phone keyboard hides behind its symbol pages, plus Tab,
/// history and Ctrl-C, which it does not have at all.
private final class DevOpsKeyRow: UIInputView {
    private weak var coordinator: DevOpsPromptField.Coordinator?
    private static let keys: [(label: String, accessibility: String, send: String?)] = [
        ("tab", "Tab", nil), ("^C", "Interrupt", nil), ("↑", "Previous command", nil), ("↓", "Next command", nil),
        ("←", "Move left", nil), ("→", "Move right", nil),
        ("|", "Pipe", "|"), (">", "Redirect", ">"), ("-", "Dash", "-"), ("/", "Slash", "/"), ("~", "Home", "~"),
        ("$", "Dollar", "$"), ("*", "Asterisk", "*"), ("&", "Ampersand", "&"), (";", "Semicolon", ";"),
        ("\"", "Double quote", "\""), ("'", "Quote", "'"), ("=", "Equals", "="), ("{", "Brace", "{"), ("}", "Close brace", "}"),
    ]

    init(coordinator: DevOpsPromptField.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 48), inputViewStyle: .default)
        autoresizingMask = .flexibleWidth
        allowsSelfSizing = true
        // The row belongs to the terminal, which is dark in both appearances.
        overrideUserInterfaceStyle = .dark
        backgroundColor = DevOpsTerminalStyle.uiBackground

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, key) in Self.keys.enumerated() {
            stack.addArrangedSubview(button(key.label, accessibility: key.accessibility, tag: index))
        }
        scroll.addSubview(stack)

        let hide = UIButton(type: .system)
        hide.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        hide.tintColor = UIColor(DevOpsTerminalStyle.text)
        hide.accessibilityLabel = "Hide keyboard"
        hide.translatesAutoresizingMaskIntoConstraints = false
        hide.addAction(UIAction { [weak self] _ in self?.coordinator?.hideKeyboard() }, for: .touchUpInside)

        addSubview(scroll)
        addSubview(hide)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: hide.leadingAnchor, constant: -4),
            hide.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -6),
            hide.centerYAnchor.constraint(equalTo: centerYAnchor),
            hide.widthAnchor.constraint(equalToConstant: 40),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 48) }

    private func button(_ title: String, accessibility: String, tag: Int) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = UIColor(DevOpsTerminalStyle.surface)
        configuration.baseForegroundColor = UIColor(DevOpsTerminalStyle.text)
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        configuration.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .medium),
        ]))
        let button = UIButton(configuration: configuration)
        button.tag = tag
        button.accessibilityLabel = accessibility
        button.accessibilityIdentifier = "devops.key.\(title)"
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func tapped(_ sender: UIButton) {
        guard let coordinator else { return }
        UIDevice.current.playInputClick()
        let key = Self.keys[sender.tag]
        if let text = key.send { coordinator.insert(text); return }
        switch key.label {
        case "tab": coordinator.tab()
        case "↑": coordinator.up()
        case "↓": coordinator.down()
        case "←": coordinator.move(-1)
        case "→": coordinator.move(1)
        case "^C": coordinator.interrupt()
        default: break
        }
    }
}

extension DevOpsKeyRow: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
