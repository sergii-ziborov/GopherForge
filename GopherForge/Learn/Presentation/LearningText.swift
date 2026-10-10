import Foundation

/// Splits authored lesson prose from fenced code without displaying Markdown fences.
enum LearningText {
    enum Block: Equatable, Sendable {
        case paragraph(String)
        case code(String)
    }
    static func blocks(in text: String) -> [Block] {
        var blocks: [Block] = []
        var lines: [String] = []
        var isCode = false
        func flush() {
            guard !lines.isEmpty else { return }
            let content = lines.joined(separator: "\n")
            let indented = !isCode && lines.allSatisfy { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
            if indented {
                blocks.append(.code(lines.map { String($0.dropFirst($0.hasPrefix("\t") ? 1 : 4)) }.joined(separator: "\n")))
            } else {
                blocks.append(isCode ? .code(content) : .paragraph(content))
            }
            lines.removeAll()
        }
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                flush()
                isCode.toggle()
            } else if !isCode && line.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
            } else {
                lines.append(line)
            }
        }
        flush()
        return blocks
    }
}
