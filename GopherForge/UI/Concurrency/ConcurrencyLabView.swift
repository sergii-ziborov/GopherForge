import SwiftUI

/// The lab: a shelf of runnable scenarios, grouped by what they are about.
///
/// It used to be one screen with a dropdown at the top. Four scenarios hidden
/// behind a menu is four scenarios nobody knows exist — you cannot browse a
/// picker, and the screen underneath was doing five jobs at once. The scenarios
/// are on a shelf now, and each one gets a page.
struct ConcurrencyLabView: View {
    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                intro

                ForEach(ConcurrencyLabScenario.Family.allCases) { family in
                    let scenarios = ConcurrencyLabScenario.all.filter { $0.family == family }
                    if !scenarios.isEmpty {
                        section(family, scenarios: scenarios)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Concurrency Lab")
        .navigationBarTitleDisplayMode(.inline)
        // The lab as a whole is what a test picks a scenario from, so the
        // identifier that used to name the dropdown names the shelf.
        .accessibilityIdentifier(AccessibilityID.labScenarioPicker)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(ConcurrencyLabScenario.all.count) programs that really run")
                .font(.title3.weight(.semibold))
            Text("""
            Each one is a Go program the bundled toolchain compiles and runs on \
            this device. What the lab draws afterwards is what the program \
            itself reported doing — the instrumentation is ordinary code you can \
            read, not a hook into the runtime.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(
        _ family: ConcurrencyLabScenario.Family,
        scenarios: [ConcurrencyLabScenario]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Label(family.title, systemImage: family.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GopherForgeTheme.accent)
                    .textCase(.uppercase)
                Text(family.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(scenarios) { scenario in
                    NavigationLink {
                        ConcurrencyScenarioView(scenario: scenario)
                    } label: {
                        ScenarioCard(scenario: scenario)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.labScenario(scenario.id))
                }
            }
        }
    }
}

/// A scenario as something to choose. The question is on the card and the
/// answer is not: the lab's whole method is predict, then run.
private struct ScenarioCard: View {
    let scenario: ConcurrencyLabScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scenario.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Text(scenario.question)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            HStack(spacing: 5) {
                ForEach(scenario.conceptTags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GopherForgeTheme.accentWash(0.12), in: Capsule())
                        .foregroundStyle(GopherForgeTheme.accent)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(GopherForgeTheme.accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GopherForgeTheme.accentWash(0.22), lineWidth: 1)
        }
    }
}
