import SwiftUI

struct DevOpsHomeView: View {
    @Environment(LearnProgress.self) private var progress
    @State private var downloads = CourseDownloadsModel.shared
    static let scratchpad = DevOpsLab(
        id: "scratchpad", title: "Terminal playground",
        objective: "Run shell commands and scripts in your private /lab.",
        instructions: "Type commands at the prompt. Files, variables, functions and your working directory persist; Reset clears this playground only. Bash syntax runs locally, with no Linux processes or remote connections.",
        initialFiles: [
            "README.txt": """
                Welcome to the GopherForge terminal.

                Everything here runs on your device, in a private /lab folder.
                Try these, one at a time:

                  ls -la
                  mkdir -p notes && cd notes
                  echo "hello" > hello.txt && cat hello.txt
                  nano todo.txt
                  sh ~/scripts/report.sh
                  cat ~/logs/app.log | grep ERROR | wc -l

                Tab completes names, the arrow keys bring back earlier
                commands, and help lists everything the shell understands.

                """,
            "logs/app.log": """
                2026-11-10T09:12:01Z INFO  api    started on :8080
                2026-11-10T09:12:07Z INFO  api    GET /health 200 2ms
                2026-11-10T09:13:44Z WARN  db     slow query 840ms
                2026-11-10T09:14:02Z ERROR api    POST /login 500 timeout
                2026-11-10T09:14:05Z INFO  api    GET /health 200 3ms
                2026-11-10T09:15:31Z ERROR worker job 42 failed: disk full
                2026-11-10T09:16:00Z INFO  api    GET /orders 200 18ms

                """,
            "scripts/report.sh": """
                #!/bin/sh
                # Summarise the log by level, the way an on-call check might.
                log=~/logs/app.log
                echo "Log report for $log"
                for level in INFO WARN ERROR; do
                  count=$(grep -c " $level " "$log")
                  printf '%-6s %s\\n' "$level" "$count"
                done
                errors=$(grep -c ' ERROR ' "$log")
                if [ "$errors" -gt 0 ]; then
                  echo "Needs attention:"
                  grep ' ERROR ' "$log" | awk '{ print "  " $3 ": " substr($0, index($0, $4)) }'
                fi

                """,
        ],
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
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open terminal")
                                Text("A Bash-style shell with its own files: pipes, grep, sed, awk, scripts and an editor.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "terminal.fill") }
                    }.accessibilityIdentifier("devops.playground")
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
