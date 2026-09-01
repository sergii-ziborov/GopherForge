import Foundation

/// The course, assembled from one file per unit.
///
/// The audience is not someone's first language. Go's own 2025 developer
/// survey found most people learn Go after starting their career, and that
/// applying idioms is a top reported friction, so every unit is written for a
/// programmer translating habits rather than meeting variables for the first
/// time.
enum GoCourseCatalog {
    static let units: [CourseUnit] = [
        CourseUnitCore.unit,
        CourseUnitCollections.unit,
        CourseUnitInterfaces.unit,
        CourseUnitErrors.unit,
        CourseUnitModules.unit,
        CourseUnitConcurrency.unit,
        CourseUnitStandardLibrary.unit,
    ]

    static var lessons: [Lesson] {
        units.flatMap(\.lessons)
    }

    static func unit(id: String) -> CourseUnit? {
        units.first { $0.id == id }
    }

    static func lesson(id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    /// The unit a lesson belongs to.
    static func unit(containing lessonID: String) -> CourseUnit? {
        units.first { unit in unit.lessons.contains { $0.id == lessonID } }
    }

    /// Where the lesson sits in its unit, counting only what the unit teaches.
    static func position(of lessonID: String) -> (index: Int, total: Int)? {
        guard let unit = unit(containing: lessonID) else { return nil }
        let teaching = unit.teachingLessons
        guard let index = teaching.firstIndex(where: { $0.id == lessonID }) else { return nil }
        return (index, teaching.count)
    }

    /// What to read next: the following lesson in this unit, or the first of
    /// the next unit once this one runs out.
    ///
    /// Challenges are not offered. They are questions with answers rather than
    /// something to build, they live in Practice, and ending a unit by dropping
    /// someone into one would be asking a question nobody walked them to.
    static func lesson(after lessonID: String) -> Lesson? {
        let ordered = units.flatMap(\.teachingLessons)
        guard let index = ordered.firstIndex(where: { $0.id == lessonID }),
              ordered.indices.contains(index + 1)
        else {
            return nil
        }
        return ordered[index + 1]
    }

    static func lessons(taggedWith conceptTag: String) -> [Lesson] {
        lessons.filter { $0.conceptTags.contains(conceptTag) }
    }

    /// Every tag the course teaches. Checked against `GoConcept.all` by the
    /// test suite so a lesson cannot introduce a tag the review scheduler and
    /// the compiler do not share.
    static var taughtConcepts: Set<String> {
        Set(lessons.flatMap(\.conceptTags))
    }
}
