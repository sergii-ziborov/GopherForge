import SwiftUI

/// What the download window is showing while a repository's modules come in.
struct ModuleDownload: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var status: String
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
                if let download = workspace.moduleDownload {
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
                            Text("Already saved. You can close this and keep going.")
                        }
                        if !download.installed.isEmpty {
                            Section("\(download.installed.count) added") {
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
                    Button("Close") { workspace.dismissModuleDownload() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}
