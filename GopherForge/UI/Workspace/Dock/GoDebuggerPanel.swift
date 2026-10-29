import SwiftUI

struct GoDebuggerPanel: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        let debugger = workspace.debugger
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(debugger.message, systemImage: debugger.state == .paused ? "pause.circle.fill" : "ladybug")
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("debug.status")
                Spacer()
                if let pause = debugger.pause {
                    Menu {
                        ForEach(Array(pause.frames.enumerated()), id: \.offset) { index, frame in
                            Button("\(frame.function) · \(frame.file):\(frame.line)") {
                                debugger.selectFrame(index)
                                workspace.select(file: frame.file, revealingLine: frame.line)
                            }
                        }
                    } label: { Label("Stack \(pause.frames.count)", systemImage: "square.3.layers.3d") }
                    .font(.caption)
                    .accessibilityIdentifier("debug.stack")
                }
            }
            HStack(spacing: 8) {
                if debugger.state == .paused {
                    control("Continue", "play.fill", "debug.continue") { debugger.resume() }
                    control("Step into", "arrow.down.to.line", "debug.stepInto") { debugger.resume(step: .into) }
                    control("Step over", "arrow.turn.down.right", "debug.stepOver") { debugger.resume(step: .over) }
                    control("Step out", "arrow.up.to.line", "debug.stepOut") { debugger.resume(step: .out) }
                } else { ProgressView().controlSize(.small); Spacer() }
                control("Stop", "stop.fill", "debug.stop") { debugger.stop() }
            }
            if let pause = debugger.pause {
                Text("\(pause.point.file):\(pause.point.line) · \(pause.point.function)")
                    .font(.caption2.monospaced()).textSelection(.enabled)
                    .accessibilityIdentifier("debug.location")
                if debugger.selectedFrame == 0 {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            if pause.locals.isEmpty { Text("No locals in this scope").foregroundStyle(.secondary) }
                            ForEach(pause.locals.keys.sorted(), id: \.self) { name in
                                Text("\(name) = \(pause.locals[name] ?? "")")
                                    .textSelection(.enabled).accessibilityIdentifier("debug.local.\(name)")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption2.monospaced())
                    .frame(height: min(88, max(22, CGFloat(pause.locals.count) * 18)))
                } else {
                    Text("Locals are captured for the current frame.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private func control(_ label: String, _ icon: String, _ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
    }
}
