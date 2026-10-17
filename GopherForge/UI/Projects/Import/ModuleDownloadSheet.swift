import SwiftUI

/// What the download window is showing while a repository's modules come in.
struct ModuleDownload: Equatable {
    var title: String
    var status: String
    /// Vendored before this download started.
    var alreadyInstalled: [String]
    /// Fetched during this download.
    var installed: [String]
    var failure: String?
}

/// Progress for the packages being fetched. Swipe down to keep what has
/// already been saved and leave the rest for Output. The list scrolls, and
/// the layout is just a list so turning the phone does not tear it.
struct ModuleDownloadSheet: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        NavigationStack {
            Group {
                if let download = workspace.downloadProgress {
                    List {
                        Section {
                            HStack(spacing: 10) {
                                if download.failure == nil {
                                    ProgressView()
                                } else {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.red)
                                }
                                Text(download.status)
                                    .font(.callout)
                            }
                            if let failure = download.failure {
                                Text(failure)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            Text(download.title)
                        } footer: {
                            Text("Closing this keeps the download going. Progress stays in Output.")
                        }
                        if !download.alreadyInstalled.isEmpty {
                            Section("Already in this project · \(download.alreadyInstalled.count)") {
                                ForEach(download.alreadyInstalled, id: \.self) { module in
                                    Label(module, systemImage: "checkmark.circle")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        if !download.installed.isEmpty {
                            Section("Added now · \(download.installed.count)") {
                                ForEach(download.installed, id: \.self) { module in
                                    Label(module, systemImage: "shippingbox")
                                        .font(.callout)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Downloading packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { workspace.hideDownloadSheet() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}
