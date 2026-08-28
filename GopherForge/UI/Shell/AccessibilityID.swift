import Foundation

/// Stable identifiers for UI tests.
///
/// Tests address these rather than visible text: a copy edit should not break a
/// test, and a test that matches on wording quietly stops checking behaviour
/// the moment the wording changes.
enum AccessibilityID {
    static func section(_ section: AppSection) -> String { "section.\(section.rawValue)" }
    static func template(_ id: String) -> String { "template.\(id)" }
    static func unit(_ id: String) -> String { "unit.\(id)" }
    static func lesson(_ id: String) -> String { "lesson.\(id)" }
    static func phase(_ phase: CompilationResult.Phase) -> String { "phase.\(phase.rawValue)" }
    static func file(_ path: String) -> String { "file.\(path)" }

    static let welcomeCard = "projects.welcome"
    static let openFolder = "projects.openFolder"
    static let editor = "workspace.editor"
    static let toolchainBanner = "workspace.toolchainBanner"
    static let dockPicker = "workspace.dockPicker"
    static let reviewEntry = "learn.review"
    static let labEntry = "learn.lab"
    static let labScenarioPicker = "lab.scenarioPicker"
    static let labRun = "lab.run"
    static let labPrediction = "lab.prediction"
    static let lessonCheck = "lesson.check"
    static let settingsToolchainStatus = "settings.toolchainStatus"
    static let settingsClearCache = "settings.clearCache"
    static let buildProgress = "workspace.buildProgress"
    static let settingsAppearance = "settings.appearance"
    static let drillBoard = "drill.board"
    static let drillProgress = "drill.progress"
    static let drillComplete = "drill.complete"
    static let drillRestart = "drill.restart"
    static let drillsEntry = "learn.drills"
    static let achievementsEntry = "learn.achievements"
    static let examplesEntry = "learn.examples"
    static let exampleOpen = "example.open"
    static let packagesEntry = "projects.packages"
    static let packageLookup = "package.lookup"
    static let packageVersion = "package.version"
    static let packageInstall = "package.install"
    static let packageInstalled = "package.installed"
    static let packageSignals = "package.signals"
    static let packageError = "package.error"
    static let fileSearch = "files.search"
    static let filesToggle = "workspace.filesToggle"
    static let exportProject = "projects.export"
    static let outputImages = "output.images"
    static let quizEntry = "unit.quiz"
    static let quizProgress = "quiz.progress"
    static let quizQuestion = "quiz.question"
    static let quizContinue = "quiz.continue"
    static let quizSummary = "quiz.summary"
    static let quizRestart = "quiz.restart"
    static let lessonComplete = "lesson.complete"
    static let lessonCompleted = "lesson.completed"
    static let practiceEntry = "learn.practice"
    static let gameCenterStatus = "gamecenter.status"
    static let gameCenterDashboard = "gamecenter.dashboard"
    static let gameCenterConnect = "gamecenter.connect"
    static let settingsResetProgress = "settings.resetProgress"
}
