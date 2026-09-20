import SwiftUI

/// Hint, the extra gotcha, and Realize when a verified answer exists.
struct LessonHintCard: View {
    let hint: LessonHint
    let canRealize: Bool
    let tint: Color
    let onRealize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hint", systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)

            Text(hint.hint)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.lessonHint)

            Text(hint.nuance)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.lessonNuance)

            if canRealize {
                Button(action: onRealize) {
                    Label("Realize", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.lessonRealize)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
