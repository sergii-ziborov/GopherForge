import SwiftUI

struct DevOpsHomeView: View {
    @Environment(LearnProgress.self) private var progress
    @State private var downloads = CourseDownloadsModel.shared
    static let scratchpad = DevOpsLab(
        id: "scratchpad", title: "Terminal playground",
        objective: "Run shell commands and scripts in your private /lab.",
        instructions: "Use help to list supported commands. Edit the script and press Run. Files, variables and your working directory persist between runs; Reset clears this playground only. This is a local shell subset, with no Linux processes or remote connections.",
        initialFiles: ["README.txt": "Welcome to the GopherForge terminal playground.\nTry: mkdir notes; echo hello > notes/hello.txt; cat notes/hello.txt\n"],
        starter: "help\npwd\nls\n", checks: [])
    var body: some View {
        let _ = downloads.revision
        if downloads.library.isInstalled("devops") {
            List {
                Section {
                    Text("Learn the command line, delivery and reliability. Shell labs execute locally in a private filesystem and work offline after downloading the course.")
                }
                if let lesson = progress.resumeLesson, ["operations", "containers", "kubernetes", "devops"].contains(GoCourseCatalog.unit(containing: lesson.id)?.id ?? "") {
                    NavigationLink("Continue: " + lesson.title) { LessonDetailView(lesson: lesson) }
                }
                Section("Terminal playground") {
                    NavigationLink { DevOpsLabView(lab: Self.scratchpad) } label: {
                        Label("Open terminal playground", systemImage: "terminal.fill")
                    }.accessibilityIdentifier("devops.playground")
                    Text("Try your own commands and scripts. Files and the current script persist separately from the guided labs.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Terminal labs") {
                    ForEach(downloads.library.packages.flatMap(\.labs)) { lab in
                        NavigationLink { DevOpsLabView(lab: lab) } label: {
                            Label { VStack(alignment: .leading) { Text(lab.title); Text(lab.objective).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "terminal") }
                        }.accessibilityIdentifier("devops.lab.\(lab.id)")
                    }
                }
                Section("Course units") {
                    ForEach(GoCourseCatalog.units.filter { ["operations", "containers", "kubernetes", "devops"].contains($0.id) }) { unit in
                        NavigationLink { UnitDetailView(unit: unit) } label: {
                            VStack(alignment: .leading) { Text(unit.title); Text(unit.summary).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }.accessibilityIdentifier("devops.home")
        } else {
            CourseDownloadPrompt(courseID: "devops")
        }
    }
}
