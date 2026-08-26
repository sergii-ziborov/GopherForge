import SwiftUI

/// The dock under the editor: problems, output, tests and idioms.
///
/// Four fixed tabs rather than a scrolling console, because each answers a
/// different question and mixing them is how a build log becomes unreadable.
struct BuildDockView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case problems
        case output
        case tests
        case idioms

        var id: String { rawValue }

        var title: String {
            switch self {
            case .problems: "Problems"
            case .output: "Output"
            case .tests: "Tests"
            case .idioms: "Idioms"
            }
        }
    }

    @Environment(WorkspaceModel.self) private var workspace
    @State private var tab: Tab = .problems

    var body: some View {
        VStack(spacing: 0) {
            Picker("Dock", selection: $tab) {
                ForEach(Tab.allCases) { item in
                    Text(badgedTitle(for: item)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            Group {
                switch tab {
                case .problems: DiagnosticListView(diagnostics: workspace.lastResult?.diagnostics ?? [])
                case .output: OutputStreamView(result: workspace.lastResult)
                case .tests: TestResultListView(tests: workspace.lastResult?.tests ?? [])
                case .idioms: IdiomFindingListView(findings: workspace.idiomFindings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 260)
        .background(Color(.secondarySystemBackground))
    }

    private func badgedTitle(for tab: Tab) -> String {
        let count = switch tab {
        case .problems: workspace.lastResult?.diagnostics.count ?? 0
        case .output: 0
        case .tests: workspace.lastResult?.tests.count ?? 0
        case .idioms: workspace.idiomFindings.count
        }
        return count > 0 ? "\(tab.title) \(count)" : tab.title
    }
}
