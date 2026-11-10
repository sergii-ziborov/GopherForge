import SwiftUI
import UniformTypeIdentifiers

/// Every course in the catalog, on this device or not.
///
/// It used to be a list of paragraphs with a "Download complete course" button
/// buried in each section, which read as settings rather than as a choice of
/// what to study. Now each course is a card: what it holds, whether it is
/// offline, and the one thing to do with it.
struct CourseDownloadsView: View {
    @State private var downloads = CourseDownloadsModel.shared
    @State private var importing = false
    @State private var removing: CourseDownload?
    @State private var exported: CourseExport?
    private struct CourseExport: Identifiable { let id = UUID(); let url: URL }

    private var installed: [CourseDownload] { downloads.library.catalog.filter { downloads.library.isInstalled($0.id) } }
    private var available: [CourseDownload] { downloads.library.catalog.filter { !downloads.library.isInstalled($0.id) } }

    var body: some View {
        let _ = downloads.revision
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !installed.isEmpty {
                    courses("My courses", installed)
                }
                if !available.isEmpty {
                    courses(installed.isEmpty ? "Choose a course" : "More courses", available)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("A course downloads only when you tap Download, then works offline. Removing it keeps your progress and drafts.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Import a course file", systemImage: "square.and.arrow.down") { importing = true }
                        .font(.footnote.weight(.semibold))
                        .disabled(downloads.downloadingID != nil)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Course downloads")
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("courses.downloads")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result { case let .success(url): downloads.importCourse(url); case let .failure(error): downloads.error = error.localizedDescription }
        }
        // An alert rather than a confirmation dialog, whose arrow points at the
        // menu that has already closed.
        .alert("Remove downloaded course?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            if let course = removing { Button("Remove \(course.title)", role: .destructive) { downloads.remove(course); removing = nil } }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: { Text("Progress, bookmarks, projects and your lesson drafts stay on this device. You can download the course again.") }
        .alert("Course download", isPresented: Binding(get: { downloads.error != nil }, set: { if !$0 { downloads.error = nil } })) {
            Button("OK") { downloads.error = nil }
        } message: { Text(downloads.error ?? "") }
        .sheet(item: $exported) { item in
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Complete course content, examples and checks. Personal progress, drafts and lab files are stored separately.")
                    ShareLink("Save or share course", item: item.url)
                }.padding().navigationTitle("Export course")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { exported = nil } } }
            }
        }
    }

    private func courses(_ title: String, _ items: [CourseDownload]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold())
            ForEach(items) { course in
                CourseDownloadCard(course: course, onExport: export, onRemove: { removing = $0 })
            }
        }
    }

    private func export(_ course: CourseDownload) {
        do { exported = CourseExport(url: try downloads.library.export(course)) }
        catch { downloads.error = error.localizedDescription }
    }
}

/// Stands where a course would be until it is downloaded: the course itself,
/// with its Download button, rather than directions to another screen.
struct CourseDownloadPrompt: View {
    @State private var downloads = CourseDownloadsModel.shared
    let courseID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let course = downloads.library.catalog.first(where: { $0.id == courseID }) {
                    CourseDownloadCard(course: course)
                }
                Text("Download once, then study offline. Lessons never download on their own.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }
}

/// One course: what it holds, whether it is on this device, and what to do
/// with it now. A course that is not downloaded is shown all the same, with
/// its size beside the button, the way the Crabrix library does it.
struct CourseDownloadCard: View {
    @Environment(LearnProgress.self) private var progress
    @State private var downloads = CourseDownloadsModel.shared
    let course: CourseDownload
    /// Present only on the downloads screen, which owns the export sheet and
    /// the removal alert. Inline on Learn the card only ever downloads.
    var onExport: ((CourseDownload) -> Void)?
    var onRemove: ((CourseDownload) -> Void)?

    private var isInstalled: Bool { downloads.library.isInstalled(course.id) }
    private var isDownloading: Bool { downloads.downloadingID == course.id }
    private var size: String { ByteCountFormatter.string(fromByteCount: Int64(course.byteCount), countStyle: .file) }
    private var hasUpdate: Bool { isInstalled && downloads.library.installedRevision(course.id) != course.revision }

    var body: some View {
        let _ = downloads.revision
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: Self.symbol(course.id))
                    .font(.title3)
                    .foregroundStyle(Self.tint(course.id))
                    .frame(width: 44, height: 44)
                    .background(Self.tint(course.id).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.title).font(.headline)
                    if isInstalled {
                        Label("Offline", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        if completion == nil { Text(contents).font(.caption).foregroundStyle(.secondary) }
                    } else {
                        Text(contents).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if isInstalled { manage } else if !isDownloading { download }
            }
            if !isInstalled {
                Text(course.summary).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let done = completion {
                VStack(spacing: 6) {
                    HStack {
                        Text("\(done.count) of \(done.total) lessons")
                        Spacer()
                        Text("\(Int((Double(done.count) / Double(max(done.total, 1)) * 100).rounded()))%")
                    }
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                    ProgressView(value: Double(done.count), total: Double(max(done.total, 1))).tint(Self.tint(course.id))
                }
            }
            if isDownloading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Downloading \(size)…").font(.caption)
                    Spacer()
                    Button("Cancel") { downloads.cancel() }.font(.caption.bold())
                }
            } else if hasUpdate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle").foregroundStyle(GopherForgeTheme.accent)
                    Text("New lessons available").font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Button("Update") { downloads.download(course) }
                        .buttonStyle(.bordered).tint(GopherForgeTheme.accent).font(.caption.bold())
                        .disabled(downloads.downloadingID != nil)
                        .accessibilityLabel("Update \(course.title), \(size)")
                }
            }
            if let failure = downloads.failedDownload, failure.id == course.id, !isDownloading {
                Label(failure.message, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(GopherForgeTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("courses.card.\(course.id)")
    }

    private var download: some View {
        VStack(spacing: 3) {
            Button { downloads.download(course) } label: {
                Label("Download", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(GopherForgeTheme.accent)
            .font(.caption.bold())
            .disabled(downloads.downloadingID != nil)
            .accessibilityLabel("Download \(course.title), \(size)")
            .accessibilityIdentifier("courses.download.\(course.id)")
            Text(size).font(.caption2.monospaced()).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var manage: some View {
        if onExport != nil || onRemove != nil {
            Menu {
                if let onExport { Button("Export course", systemImage: "square.and.arrow.up") { onExport(course) } }
                if let onRemove {
                    Button("Remove download", systemImage: "trash", role: .destructive) { onRemove(course) }
                        .accessibilityIdentifier("courses.remove.\(course.id)")
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44)
            }
            .disabled(downloads.downloadingID != nil)
            .accessibilityLabel("Manage \(course.title)")
            .accessibilityIdentifier("courses.manage.\(course.id)")
        }
    }

    private var contents: String {
        if course.interviewCount > 0 { return "\(course.interviewCount) interview guides" }
        var parts = ["\(course.unitCount) units", "\(course.teachingCount) lessons"]
        if course.labCount > 0 { parts.append("\(course.labCount) terminal labs") }
        return parts.joined(separator: " · ")
    }

    /// Teaching lessons only, the same count the Learn screen shows; an
    /// interview bank has no lessons to count.
    private var completion: (count: Int, total: Int)? {
        guard let package = downloads.library.packages.first(where: { $0.id == course.id }) else { return nil }
        let lessons = package.units.flatMap(\.teachingLessons)
        guard !lessons.isEmpty else { return nil }
        return (lessons.count { progress.completed.contains($0.id) }, lessons.count)
    }

    private static func symbol(_ id: String) -> String {
        switch id {
        case "go": "chevron.left.forwardslash.chevron.right"
        case "devops": "terminal"
        case "interview": "person.crop.rectangle.stack"
        default: "book.closed"
        }
    }

    private static func tint(_ id: String) -> Color {
        switch id {
        case "devops": GopherForgeTheme.aqua
        case "interview": GopherForgeTheme.berry
        default: GopherForgeTheme.gopherBlue
        }
    }
}
