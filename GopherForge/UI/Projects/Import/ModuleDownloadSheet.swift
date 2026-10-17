import SwiftUI

/// What the download window is showing while a repository's modules come in.
struct ModuleDownload: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var status: String
    var installed: [String]
    var failure: String?
}

/// Shown while packages are downloading. It closes when that pass finishes.
/// A package that could not be fetched is reported in Output, and the project
/// still opens.
struct ModuleDownloadSheet: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let download = workspace.moduleDownload {
                    Text(download.title)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 10) {
                        if download.failure == nil {
                            ProgressView()
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                        Text(download.status)
                            .font(.callout)
                            .foregroundStyle(download.failure == nil ? Color.primary : Color.red)
                    }
                    if let failure = download.failure {
                        Text(failure)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !download.installed.isEmpty {
                        Text("\(download.installed.count) added")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(download.installed, id: \.self) { module in
                                    Label(module, systemImage: "shippingbox")
                                        .font(.callout)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Downloading packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if workspace.moduleDownload?.failure != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Close") { workspace.dismissModuleDownload() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(workspace.moduleDownload?.failure == nil)
        .presentationDetents([.medium, .large])
    }
}
