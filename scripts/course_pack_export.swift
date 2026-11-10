import Foundation
struct GoSourceSnapshot { let files: [String:String]; let packagePattern: String; let entryFile: String; let workspaceReuseKey: String }
enum GoLanguage { static func module(_ name:String)->String { "module \(name)\n\ngo 1.27\n" } }
@main struct ExportCoursePacks {
 static func main() throws {
  let resources = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent()
  let destination = URL(fileURLWithPath: CommandLine.arguments[2])
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
  let guides = try JSONDecoder().decode([LessonGuide].self, from: Data(contentsOf: resources.appending(path: "LessonGuides.json")))
  let interview = try JSONDecoder().decode(InterviewPrepBank.self, from: Data(contentsOf: resources.appending(path: "InterviewPrep.json")))
  let labs = try JSONDecoder().decode([DevOpsLab].self, from: Data(contentsOf: resources.appending(path: "DevOpsLabs.json")))
  let devops: Set<String> = ["operations", "containers", "kubernetes", "devops"]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  for id in ["go", "devops", "interview"] {
   let units = id == "interview" ? [] : GoCourseCatalog.units.filter { devops.contains($0.id) == (id == "devops") }
   let unitIDs = Set(units.map(\.id))
   let lessonIDs = Set(units.flatMap(\.lessons).map(\.id))
   let pack = CoursePackage(schemaVersion: 1, id: id, revision: "2026-11-07.1", units: units,
      readings: ReadingLessonCatalog.all.filter { lessonIDs.contains($0.id) },
      guides: guides.filter { lessonIDs.contains($0.id) },
      hints: LessonHintCatalog.allAuthored.values.filter { lessonIDs.contains($0.id) }.sorted { $0.id < $1.id },
      solutions: Dictionary(uniqueKeysWithValues: lessonIDs.sorted().compactMap { key in LessonSolutionCatalog.solution(for: key).map { (key, $0) } }),
      interview: id == "interview" ? interview : nil, labs: id == "devops" ? labs : [],
      practice: CoursePractice(quizzes: QuizCatalog.all.filter { unitIDs.contains($0.unitID) },
       drills: MatchingDrillCatalog.drills.filter { unitIDs.contains($0.unitID) },
       bugs: SpotTheBugCatalog.all.filter { unitIDs.contains($0.unitID) },
       interviews: InterviewCatalog.all.filter { unitIDs.contains($0.unitID) },
       reviewRounds: ReviewMatchCatalog.rounds.filter { unitIDs.contains($0.unitID) },
       reviewPairs: ReviewMatchCatalog.additionalPairs.filter { $0.requiredLessonID.map { lessonIDs.contains($0) } ?? false }))
   try encoder.encode(pack).write(to: destination.appending(path: "\(id)-\(pack.revision).gfcourse.json"))
  }
 }
}
