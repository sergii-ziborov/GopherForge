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
