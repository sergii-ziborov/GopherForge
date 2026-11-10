import Foundation

enum MatchingDrillCatalog {
    static var drills: [MatchingDrill] { CourseLibrary.shared.packages.flatMap { $0.practice.drills } }
    static func drill(id: String) -> MatchingDrill? { drills.first { $0.id == id } }
    static func drills(forUnit unitID: String) -> [MatchingDrill] { drills.filter { $0.unitID == unitID } }
}
enum SpotTheBugCatalog {
    static var all: [SpotTheBugRound] { CourseLibrary.shared.packages.flatMap { $0.practice.bugs } }
    static func rounds(forUnit unitID: String) -> [SpotTheBugRound] { all.filter { $0.unitID == unitID } }
}
enum InterviewCatalog {
    static var all: [InterviewQuestion] { CourseLibrary.shared.packages.flatMap { $0.practice.interviews } }
    static func questions(forUnit unitID: String) -> [InterviewQuestion] { all.filter { $0.unitID == unitID } }
}
