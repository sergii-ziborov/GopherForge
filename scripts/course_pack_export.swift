import Foundation
struct GoSourceSnapshot { let files: [String:String]; let packagePattern: String; let entryFile: String; let workspaceReuseKey: String }
enum GoLanguage { static func module(_ name:String)->String { "module \(name)\n\ngo 1.27\n" } }
@main struct ExportCoursePacks {
 // A revision changes only when that course's document changes, so an
 // unchanged course keeps its published bytes and installed copies stay current.
 static let revisions = ["go": "2026-11-18.1", "devops": "2026-11-07.1", "interview": "2026-11-07.1",
                         "gin": "2026-11-18.2", "blockchain": "2026-11-18.1", "security": "2026-11-18.1", "gamedev": "2026-11-18.1"]
 static func main() throws {
  let resources = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent()
  let destination = URL(fileURLWithPath: CommandLine.arguments[2])
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
  let guides = try JSONDecoder().decode([LessonGuide].self, from: Data(contentsOf: resources.appending(path: "LessonGuides.json")))
  let interview = try JSONDecoder().decode(InterviewPrepBank.self, from: Data(contentsOf: resources.appending(path: "InterviewPrep.json")))
  let labs = try JSONDecoder().decode([DevOpsLab].self, from: Data(contentsOf: resources.appending(path: "DevOpsLabs.json")))
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  let courses = ["go", "devops", "interview"] + CourseMembership.specialized.map(\.id)
  // Every unit is published exactly once.
  let unitIDs = GoCourseCatalog.units.map(\.id)
  precondition(Set(unitIDs).count == unitIDs.count && unitIDs.allSatisfy { courses.contains(CourseMembership.courseID(forUnit: $0)) })
  for id in courses {
   let units = id == "interview" ? [] : GoCourseCatalog.units.filter { CourseMembership.courseID(forUnit: $0.id) == id }
   let unitIDs = Set(units.map(\.id))
   let lessonIDs = Set(units.flatMap(\.lessons).map(\.id))
   let pack = CoursePackage(schemaVersion: 1, id: id, revision: revisions[id]!, units: units,
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
