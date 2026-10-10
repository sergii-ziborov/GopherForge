import SwiftUI

/// Embedded: the lesson owns vertical scrolling. Expanded: the editor owns it.
struct LessonEditorCard: View {
    @Binding var text: String
    let canCheck: Bool
    let isChecking: Bool
    let onCheck: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("main.go", systemImage: "doc.text")
                    .font(.caption.monospaced().weight(.semibold))
                Spacer()
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    expanded = true
                } label: {
                    Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityIdentifier("lesson.editor.expand")
            }
            .padding(12)
            Divider()
            SyntaxCodeEditor(text: $text, fileKind: .go, fontSize: 13, scrollsVertically: false)
                .frame(height: SyntaxCodeEditor.embeddedHeight(for: text, fontSize: 13))
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fullScreenCover(isPresented: $expanded) {
            NavigationStack {
                SyntaxCodeEditor(text: $text, fileKind: .go, fontSize: 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .navigationTitle("main.go")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back to lesson", systemImage: "chevron.down") { expanded = false }
                                .accessibilityIdentifier("lesson.editor.collapse")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: onCheck) {
                                if isChecking { ProgressView() }
                                else { Label("Check", systemImage: "checkmark.diamond") }
                            }
                            .disabled(!canCheck)
                            .accessibilityIdentifier("lesson.editor.check")
                        }
                    }
            }
        }
    }
}
